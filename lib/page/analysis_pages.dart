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

enum _AnalysisStep { capture, analyzingImage, reviewFoods, nutrientAnalysis, deleting }

class AnalysisScreen extends StatefulWidget {
  final String? mealType; // 식사 타입: '아침', '점심', '간식', '저녁'
  final DateTime? selectedDate; // 선택된 날짜
  final Function(Map<String, dynamic>)? onAnalysisComplete; // 분석 완료 콜백
  final List<String>? existingFoods; // 편집 모드일 때 기존 음식 목록

  const AnalysisScreen({
    super.key,
    this.mealType,
    this.selectedDate,
    this.onAnalysisComplete,
    this.existingFoods,
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
  List<String> _deletedFoods = []; // 삭제된 음식 목록 (저장 시 사용)

  @override
  void initState() {
    super.initState();
    if (widget.existingFoods != null && widget.existingFoods!.isNotEmpty) {
      _foodItems.addAll(widget.existingFoods!);
      _currentStep = _AnalysisStep.reviewFoods;
      debugPrint('✅ [AnalysisScreen] 편집 모드: 기존 음식 ${_foodItems.length}개 로드');
    }
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final imageFile = File(picked.path);
      setState(() {
        _selectedImage = imageFile;
        _currentStep = _AnalysisStep.analyzingImage;
      });

      try {
        final storageService = StorageService();
        final imageUrl = await storageService.uploadImage(
          imageFile: imageFile,
          folder: 'meal_images',
        );

        setState(() {
          _uploadedImageUrl = imageUrl;
        });

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
            _savedImageId = imageData['id'] as int?;
            debugPrint('✅ [AnalysisScreen] 이미지 DB 저장 완료: image_id=$_savedImageId');
          } catch (e) {
            debugPrint('⚠️ [AnalysisScreen] 이미지 DB 저장 실패: $e');
          }

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
            if (widget.existingFoods == null || widget.existingFoods!.isEmpty) {
              _foodItems.clear();
            }
            if (foods.isNotEmpty) {
              _foodItems.addAll(
                foods.map((f) => f['name'] as String).toList(),
              );
            }
          });
        } else {
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
            });
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AnalysisScreen] 이미지 분석 중 예외 발생: $e');
      debugPrint('   스택 트레이스: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 분석에 실패했습니다. 음식을 수동으로 입력해주세요.'),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _currentStep = _AnalysisStep.reviewFoods;
        });
      }
    }
  }

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
      final deletedFood = _foodItems[index];
      setState(() {
        _foodItems.removeAt(index);
        // 삭제된 음식 이름 저장 (저장 시 사용)
        if (!_deletedFoods.contains(deletedFood)) {
          _deletedFoods.add(deletedFood);
        }
      });
    }
  }

  Future<void> _startNutrientAnalysis() async {
    // 삭제된 음식 이름 초기화 (새로운 저장 시작)
    _deletedFoods.clear();
    
    setState(() {
      _currentStep = _AnalysisStep.nutrientAnalysis;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final imageId = _savedImageId;

      // 프론트엔드 형식("아침/점심/저녁/간식")을 백엔드 형식("조식/중식/석식/야식")으로 변환
      String mealTime = widget.mealType ?? '점심';
      final mealTimeMapping = {
        '아침': '조식',
        '점심': '중식',
        '저녁': '석식',
        '간식': '야식',
      };
      mealTime = mealTimeMapping[mealTime] ?? mealTime;

      final mealDate = widget.selectedDate ?? DateTime.now();
      final mealDateStr = DateFormat('yyyy-MM-dd').format(mealDate);

      final foods = _foodItems
          .map(
            (name) => {
              'name': name,
              'confidence': 0.9,
            },
          )
          .toList();

      debugPrint('🔄 [AnalysisScreen] 식사 기록 저장 시작');
      debugPrint('   memberId: ${user.uid}');
      debugPrint('   mealTime: $mealTime (원본: ${widget.mealType})');
      debugPrint('   mealDate: $mealDateStr');
      debugPrint('   imageId: $imageId');
      debugPrint('   foods 개수: ${foods.length}');
      debugPrint('   foods 목록: ${_foodItems.join(", ")}');

      final mealApiService = MealApiService.instance;
      
      // 편집 모드일 때 또는 음식 목록이 비어있을 때: 기존 meal 삭제 후 현재 화면의 음식 목록만 저장
      // (사용자가 화면에서 삭제한 음식은 저장되지 않음)
      final isEditMode = widget.existingFoods != null && widget.existingFoods!.isNotEmpty;
      
      if (isEditMode || _foodItems.isEmpty) {
        debugPrint('🔄 [AnalysisScreen] 기존 meal 삭제 중... (편집 모드: $isEditMode, 음식 목록 비어있음: ${_foodItems.isEmpty})');
        debugPrint('   화면의 음식 목록: ${_foodItems.join(", ")}');
        if (isEditMode) {
          debugPrint('   삭제된 음식: ${widget.existingFoods!.where((f) => !_foodItems.contains(f)).join(", ")}');
        }
        try {
          await mealApiService.deleteMealsByDateAndType(
            memberId: user.uid,
            date: mealDateStr,
            mealTime: mealTime,
          );
          debugPrint('✅ [AnalysisScreen] 기존 meal 삭제 완료');
        } catch (e) {
          debugPrint('⚠️ [AnalysisScreen] 기존 meal 삭제 실패 (계속 진행): $e');
          // 삭제 실패해도 새 meal 저장은 계속 진행
        }
      }
      
      // 음식 목록이 비어있으면 저장하지 않고 DB에서 삭제만 함 (모두 삭제한 경우)
      if (_foodItems.isEmpty) {
        debugPrint('⚠️ [AnalysisScreen] 음식 목록이 비어있어 저장하지 않습니다. (기존 meal 삭제 완료)');
        
        // 삭제된 음식 이름 추적 (편집 모드일 때 기존 음식 목록과 비교)
        final isEditMode = widget.existingFoods != null && widget.existingFoods!.isNotEmpty;
        if (isEditMode && widget.existingFoods != null) {
          // 기존 음식 목록에서 현재 음식 목록을 제외한 것 = 삭제된 음식
          _deletedFoods = widget.existingFoods!.where((food) => !_foodItems.contains(food)).toList();
        }
        
        // 삭제 중 화면으로 이동
        setState(() {
          _currentStep = _AnalysisStep.deleting;
        });
        
        // 삭제 처리
        try {
          await mealApiService.deleteMealsByDateAndType(
            memberId: user.uid,
            date: mealDateStr,
            mealTime: mealTime,
          );
          debugPrint('✅ [AnalysisScreen] 기존 meal 삭제 완료');
          
          // 1.5초 후 완료 처리
          await Future.delayed(const Duration(milliseconds: 1500));
          
          if (mounted) {
            // 콜백을 통해 리포트 화면에서 데이터 재로드
            if (widget.onAnalysisComplete != null) {
              widget.onAnalysisComplete!({
                'imageUrl': _uploadedImageUrl,
                'menuText': '',
                'mealType': widget.mealType ?? '점심',
                'selectedDate': mealDate,
                'foods': <String>[],
                'total_nutrition': <String, dynamic>{},
              });
            }
            
            // 삭제된 음식 이름을 메시지에 표시
            final deletedFoodsText = _deletedFoods.isNotEmpty 
                ? _deletedFoods.join(', ')
                : '모든 음식';
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$deletedFoodsText이(가) 삭제되었습니다.')),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          debugPrint('❌ [AnalysisScreen] meal 삭제 실패: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
            );
            setState(() {
              _currentStep = _AnalysisStep.reviewFoods;
            });
          }
        }
        return;
      }
      
      final result = await mealApiService.saveMeal(
        memberId: user.uid,
        mealTime: mealTime,
        mealDate: mealDateStr,
        imageId: imageId,
        memo: _foodItems.join(', '),
        foods: foods,
      );

      debugPrint('✅ [AnalysisScreen] 식사 기록 저장 성공');
      debugPrint('   meal_id: ${result['meal_id']}');
      debugPrint('   total_nutrition: ${result['total_nutrition']}');

      if (mounted) {
        if (widget.onAnalysisComplete != null) {
          widget.onAnalysisComplete!({
            'imageUrl': _uploadedImageUrl,
            'menuText': _foodItems.join(', '),
            'mealType': widget.mealType ?? '점심',
            'selectedDate': mealDate,
            'foods': _foodItems,
            'total_nutrition': result['total_nutrition'],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('분석이 완료되었습니다. 리포트로 돌아갑니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AnalysisScreen] 식사 기록 저장 실패: $e');
      debugPrint('   스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('분석 중 오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _currentStep = _AnalysisStep.reviewFoods;
        });
      }
    }
  }

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
              if (_currentStep != _AnalysisStep.nutrientAnalysis && _currentStep != _AnalysisStep.deleting) ...[
                _buildCaptureControls(),
                const SizedBox(height: 20),
              ],
              _buildStepContent(),
              const SizedBox(height: 24),
              if (_currentStep != _AnalysisStep.nutrientAnalysis && _currentStep != _AnalysisStep.deleting) ...[
                _buildFoodInputSection(),
                const SizedBox(height: 16),
                if (_currentStep == _AnalysisStep.reviewFoods && _foodItems.isNotEmpty) ...[
                  const Text(
                    '추가된 음식',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFoodList(),
              ],
              const SizedBox(height: 24),
              if (_currentStep == _AnalysisStep.reviewFoods) ...[
                // 분석하기 버튼과 저장하기 버튼을 나란히 배치
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(),
                    ),
                    const SizedBox(width: 12),
                    _buildSaveButton(),
                  ],
                ),
              ] else ...[
                // 분석하기 버튼 (이미지 분석 단계용)
                Bounceable(
                  onTap: () {
                    if (_currentStep == _AnalysisStep.capture) {
                      // 이미지 선택 유도
                    }
                  },
                  child: _buildActionButton(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _AnalysisStep.capture:
        return _buildImagePreview();
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
        return _buildImagePreview();
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
      case _AnalysisStep.deleting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 24),
            Text(
              textAlign: TextAlign.center,
              _deletedFoods.isNotEmpty 
                  ? '${_deletedFoods.join(', ')}을(를) 삭제 중입니다.'
                  : '음식을 삭제 중입니다.',
              style: const TextStyle(
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
    debugPrint('🔍 [AnalysisScreen] _buildFoodList 호출');
    debugPrint('   _foodItems 개수: ${_foodItems.length}');
    debugPrint('   _foodItems 내용: $_foodItems');
    debugPrint('   _currentStep: $_currentStep');

    if (_foodItems.isEmpty) {
      debugPrint('   ⚠️ 음식 목록이 비어있음');
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

    debugPrint('   ✅ 음식 목록 표시: ${_foodItems.length}개');

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
    final isDisabled = _currentStep == _AnalysisStep.analyzingImage || _currentStep == _AnalysisStep.nutrientAnalysis || _currentStep == _AnalysisStep.deleting;
    final buttonLabel = _currentStep == _AnalysisStep.analyzingImage ? '분석 중...' : '분석하기';

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isDisabled
            ? null
            : () {
                // 분석하기 버튼: 원래 기능 유지 (저장까지 수행)
                _startNutrientAnalysis();
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

  Widget _buildSaveButton() {
    // 편집 모드이거나 음식이 하나라도 있으면 활성화
    final isEditMode = widget.existingFoods != null && widget.existingFoods!.isNotEmpty;
    final isDisabled = _foodItems.isEmpty && !isEditMode; // 편집 모드가 아니고 음식 목록이 비어있으면 비활성화
    final isSaving = _currentStep == _AnalysisStep.nutrientAnalysis;

    return SizedBox(
      width: 100, // 작은 버튼 크기
      child: OutlinedButton(
        onPressed: isDisabled || isSaving
            ? null
            : () {
                _startNutrientAnalysis();
              },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: ColorPalette.primary200),
          foregroundColor: ColorPalette.primary200,
        ),
        child: Text(
          isSaving ? '저장 중...' : '저장하기',
          style: const TextStyle(
            fontSize: 14,
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorPalette.primary300,
                      side: const BorderSide(color: ColorPalette.primary300),
                    ),
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
