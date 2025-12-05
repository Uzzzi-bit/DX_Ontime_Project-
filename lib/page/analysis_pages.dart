import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/color_palette.dart';
import '../service/storage_service.dart';
import '../api/meal_api_service.dart';
import '../api/image_api_service.dart';

enum _AnalysisStep { capture, analyzingImage, reviewFoods, nutrientAnalysis }

class AnalysisScreen extends StatefulWidget {
  final String? mealType; // 식사 타입: '아침', '점심', '간식', '저녁'
  final DateTime? selectedDate; // 선택된 날짜
  final Function(Map<String, dynamic>)? onAnalysisComplete; // 분석 완료 콜백

  const AnalysisScreen({
    super.key,
    this.mealType,
    this.selectedDate,
    this.onAnalysisComplete,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final TextEditingController _foodController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  _AnalysisStep _currentStep = _AnalysisStep.capture;
  final List<String> _foodItems = [];
  File? _selectedImage;
  String? _uploadedImageUrl; // 업로드된 이미지의 Firebase Storage URL
  int? _savedImageId; // Django DB에 저장된 이미지 ID

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  // [AI] [DB] 사진 선택 및 AI 이미지 분석
  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final imageFile = File(picked.path);
      setState(() {
        _selectedImage = imageFile;
        _currentStep = _AnalysisStep.analyzingImage;
      });

      // Firebase Storage에 이미지 업로드
      try {
        final storageService = StorageService();

        // 1. Firebase Storage에 이미지 업로드
        final imageUrl = await storageService.uploadImage(
          imageFile: imageFile,
          folder: 'meal_images',
        );

        setState(() {
          _uploadedImageUrl = imageUrl;
        });

        // 2. Django DB에 이미지 정보 저장하여 image_id 얻기
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final imageApiService = ImageApiService.instance;
            final imageData = await imageApiService.saveImage(
              memberId: user.uid,
              imageUrl: imageUrl,
              imageType: 'meal',
              source: 'meal_form',
            );
            // image_id 저장 (나중에 meal 저장 시 사용)
            _savedImageId = imageData['id'] as int?;
            debugPrint('✅ [AnalysisScreen] 이미지 DB 저장 완료: image_id=$_savedImageId');
          } catch (e) {
            debugPrint('⚠️ [AnalysisScreen] 이미지 DB 저장 실패: $e');
            // 이미지 DB 저장 실패해도 계속 진행
          }

          // 3. YOLO로 이미지 분석
          await _analyzeImageWithYOLO(imageFile, user.uid);
        } else {
          throw Exception('로그인이 필요합니다');
        }
      } catch (uploadError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이미지 처리 중 오류: $uploadError')),
          );
          setState(() {
            _currentStep = _AnalysisStep.capture;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 불러오지 못했습니다: $e')),
      );
      setState(() {
        _currentStep = _AnalysisStep.capture;
      });
    }
  }

  // YOLO로 이미지 분석
  Future<void> _analyzeImageWithYOLO(File imageFile, String memberId) async {
    try {
      debugPrint('🔄 [AnalysisScreen] YOLO 이미지 분석 시작');
      debugPrint('   이미지 경로: ${imageFile.path}');
      debugPrint('   이미지 존재: ${await imageFile.exists()}');

      final mealApiService = MealApiService.instance;
      final result = await mealApiService.analyzeMealImage(
        imageFile: imageFile,
        memberId: memberId,
      );

      debugPrint('📥 [AnalysisScreen] 분석 결과: $result');

      if (mounted) {
        if (result['success'] == true) {
          final foods = result['foods'] as List;
          debugPrint('✅ [AnalysisScreen] 분석 성공: ${foods.length}개 음식 탐지');

          setState(() {
            _currentStep = _AnalysisStep.reviewFoods;
            _foodItems.clear();
            if (foods.isNotEmpty) {
              _foodItems.addAll(
                foods.map((f) => f['name'] as String).toList(),
              );
            }
          });
        } else {
          // YOLO 분석 실패해도 사용자가 수동으로 음식을 입력할 수 있도록 reviewFoods 단계로 진행
          final errorMsg = result['error'] as String? ?? '알 수 없는 오류';
          debugPrint('⚠️ [AnalysisScreen] 분석 실패: $errorMsg');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('이미지 분석에 실패했습니다: $errorMsg\n음식을 수동으로 입력해주세요.'),
                duration: const Duration(seconds: 5),
              ),
            );
            setState(() {
              _currentStep = _AnalysisStep.reviewFoods;
              // 기존 음식 리스트는 유지 (사용자가 수동으로 추가 가능)
            });
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AnalysisScreen] 이미지 분석 중 예외 발생: $e');
      debugPrint('   스택 트레이스: $stackTrace');

      // YOLO 분석 실패해도 사용자가 수동으로 음식을 입력할 수 있도록 reviewFoods 단계로 진행
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 분석에 실패했습니다. 음식을 수동으로 입력해주세요.'),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _currentStep = _AnalysisStep.reviewFoods;
          // 기존 음식 리스트는 유지 (사용자가 수동으로 추가 가능)
        });
      }
    }
  }

  // TODO: [AI] AI 이미지 분석 함수 구현
  // Future<void> _analyzeImageWithAI(File imageFile) async {
  //   try {
  //     // 1. 이미지를 서버에 업로드
  //     // final imageUrl = await api.uploadImageForAnalysis(imageFile);
  //
  //     // 2. AI 서버에 분석 요청
  //     // final analysisResult = await api.analyzeMealImage(
  //     //   imageFile: imageFile,
  //     //   // 또는 imageUrl: imageUrl,
  //     // );
  //
  //     // 3. 분석 결과 처리
  //     // setState(() {
  //     //   _currentStep = _AnalysisStep.reviewFoods;
  //     //   _foodItems.clear();
  //     //   _foodItems.addAll(analysisResult.foods.map((f) => f.name));
  //     // });
  //   } catch (e) {
  //     // 에러 처리
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('이미지 분석 중 오류가 발생했습니다: $e')),
  //     );
  //   }
  // }

  void _handleAddFood() {
    final text = _foodController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _foodItems.add(text);
      _foodController.clear();
    });
  }

  Future<void> _showEditDialog(int index) async {
    final controller = TextEditingController(text: _foodItems[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return _FoodDialog(
          title: '음식 수정',
          confirmLabel: '수정',
          controller: controller,
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _foodItems[index] = result.trim();
      });
    }
  }

  Future<void> _showDeleteDialog(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _ConfirmDialog(
          target: _foodItems[index],
        );
      },
    );
    if (shouldDelete == true) {
      setState(() {
        _foodItems.removeAt(index);
      });
    }
  }

  // [AI] [DB] 영양소 분석 및 데이터베이스 저장
  Future<void> _startNutrientAnalysis() async {
    setState(() {
      _currentStep = _AnalysisStep.nutrientAnalysis;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 1. 이미지 ID 가져오기 (이미 저장된 경우)
      final imageId = _savedImageId;

      // 2. 식사 타입 및 날짜 설정
      final mealTime = widget.mealType ?? '중식';
      final mealDate = widget.selectedDate ?? DateTime.now();
      final mealDateStr = DateFormat('yyyy-MM-dd').format(mealDate);

      // 3. YOLO 분석 결과를 음식 리스트로 변환
      final foods = _foodItems
          .map(
            (name) => {
              'name': name,
              'confidence': 0.9, // YOLO 분석에서 가져온 값 사용 가능
            },
          )
          .toList();

      // 4. 식사 기록 저장 (영양소 분석 포함)
      final mealApiService = MealApiService.instance;
      final result = await mealApiService.saveMeal(
        memberId: user.uid,
        mealTime: mealTime,
        mealDate: mealDateStr,
        imageId: imageId,
        memo: _foodItems.join(', '),
        foods: foods,
      );

      if (mounted) {
        // 분석 완료 콜백 호출
        if (widget.onAnalysisComplete != null) {
          widget.onAnalysisComplete!({
            'imageUrl': _uploadedImageUrl,
            'menuText': _foodItems.join(', '),
            'mealType': mealTime,
            'selectedDate': mealDate,
            'total_nutrition': result['total_nutrition'],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('분석이 완료되었습니다. 리포트로 돌아갑니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 중 오류가 발생했습니다: $e')),
        );
        setState(() {
          _currentStep = _AnalysisStep.reviewFoods;
        });
      }
    }
  }

  // TODO: [AI] [DB] 영양소 분석 및 저장 함수 구현
  // Future<void> _analyzeNutrientsAndSave() async {
  //   try {
  //     // 1. 최종 음식 목록을 AI 서버에 전송하여 영양소 분석
  //     // final nutrientAnalysis = await api.analyzeNutrients(
  //     //   foods: _foodItems,
  //     //   mealType: widget.mealType, // report_pages에서 전달받은 mealType
  //     //   date: widget.selectedDate, // report_pages에서 전달받은 date
  //     // );
  //
  //     // 2. 분석된 사진을 서버에 업로드
  //     // final imageUrl = await api.uploadMealImage(_selectedImage!);
  //
  //     // 3. 데이터베이스에 저장
  //     // await api.saveMealRecord(
  //     //   mealType: widget.mealType,
  //     //   date: widget.selectedDate,
  //     //   imageUrl: imageUrl,
  //     //   analysisResult: nutrientAnalysis,
  //     //   menuText: _foodItems.join(', '),
  //     // );
  //
  //     // 4. 리포트 화면에 결과 전달 (콜백 또는 상태 관리)
  //     // if (widget.onAnalysisComplete != null) {
  //     //   widget.onAnalysisComplete!({
  //     //     'imageUrl': imageUrl,
  //     //     'analysisResult': nutrientAnalysis,
  //     //     'menuText': _foodItems.join(', '),
  //     //   });
  //     // }
  //
  //     // 5. 리포트 화면으로 돌아가기
  //     // Navigator.pop(context);
  //   } catch (e) {
  //     // 에러 처리
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('분석 중 오류가 발생했습니다: $e')),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.bg200,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('식단 분석'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepContent(),
              const SizedBox(height: 24),
              if (_currentStep != _AnalysisStep.nutrientAnalysis) _buildFoodInputSection(),
              if (_currentStep != _AnalysisStep.nutrientAnalysis) const SizedBox(height: 12),
              if (_currentStep != _AnalysisStep.nutrientAnalysis) _buildFoodList(),
              const SizedBox(height: 24),
              Bounceable(
                onTap: () {
                  if (_currentStep == _AnalysisStep.reviewFoods) {
                    _startNutrientAnalysis();
                  }
                },
                child: _buildActionButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _AnalysisStep.capture:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCaptureControls(),
            const SizedBox(height: 20),
            _buildImagePreview(),
          ],
        );
      case _AnalysisStep.analyzingImage:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(showOverlay: true),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '음식 사진을 분석 중입니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      case _AnalysisStep.reviewFoods:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 16),
            const Text(
              '분석된 음식 목록',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _AnalysisStep.nutrientAnalysis:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 24),
            const Text(
              textAlign: TextAlign.center,
              'AI가 사용자의 식단을 분석하고 있습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              minHeight: 8,
              backgroundColor: ColorPalette.bg200,
              valueColor: const AlwaysStoppedAnimation(ColorPalette.primary200),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColorPalette.primary100.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'TIP. 점심에는 당뇨의 위험이 큽니다. 식단을 가볍게 조절해 보세요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildCaptureControls() {
    return Row(
      children: [
        Expanded(
          child: Bounceable(
            onTap: () {},
            child: ElevatedButton.icon(
              onPressed: () => _handleImageSelection(ImageSource.camera),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: ColorPalette.primary200,
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('바로 촬영'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Bounceable(
            onTap: () {},
            child: ElevatedButton.icon(
              onPressed: () => _handleImageSelection(ImageSource.gallery),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: ColorPalette.primary200,
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('사진 선택'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview({bool showOverlay = false}) {
    final placeholder = Container(
      height: 200,
      decoration: BoxDecoration(
        color: ColorPalette.bg200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          '음식 사진을 추가해 주세요',
          style: TextStyle(color: ColorPalette.text200),
        ),
      ),
    );

    if (_selectedImage == null) {
      return placeholder;
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedImage!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (showOverlay)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: ColorPalette.bg100.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFoodInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '식단을 직접 입력해 주세요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _foodController,
                decoration: const InputDecoration(
                  hintText: '음식명을 입력하세요',
                  filled: true,
                  fillColor: ColorPalette.bg100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _handleAddFood(),
              ),
            ),
            const SizedBox(width: 8),
            Bounceable(
              onTap: () {},
              child: InkWell(
                onTap: _handleAddFood,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ColorPalette.primary200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: ColorPalette.bg100),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFoodList() {
    if (_foodItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: ColorPalette.bg100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            '추가된 음식이 없습니다.',
            style: TextStyle(color: ColorPalette.text200),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _foodItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _showDeleteDialog(index),
                  icon: const Icon(Icons.close, size: 18),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditDialog(index),
                  icon: const Icon(Icons.edit, size: 18),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton() {
    final isDisabled = _foodItems.isEmpty || _currentStep == _AnalysisStep.analyzingImage;
    final buttonLabel = _currentStep == _AnalysisStep.nutrientAnalysis ? '분석 중...' : '분석하기';

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isDisabled || _currentStep == _AnalysisStep.nutrientAnalysis
            ? null
            : () {
                if (_currentStep == _AnalysisStep.capture || _currentStep == _AnalysisStep.reviewFoods) {
                  _startNutrientAnalysis();
                }
              },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: ColorPalette.primary200,
        ),
        child: Text(
          buttonLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FoodDialog extends StatelessWidget {
  const _FoodDialog({
    required this.title,
    required this.confirmLabel,
    required this.controller,
  });

  final String title;
  final String confirmLabel;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorPalette.bg200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.target});

  final String target;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorPalette.bg200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\'${target}\'을 삭제하시겠어요?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('삭제'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
