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
  Map<String, dynamic>? _analysisResult; // 분석 결과 (DB 저장 전까지 임시 보관)
  List<String> _deletingFoods = []; // 삭제 중인 음식 목록 (UI 표시용)
  List<String> _savingFoods = []; // 저장 중인 음식 목록 (UI 표시용)
  bool _isDeleting = false; // 삭제 중인지 여부
  bool _hasAnalyzedOnce = false; // 분석하기 버튼을 눌러서 DB에 저장되었는지 여부
  List<String> _analyzedFoods = []; // 분석하기 버튼을 눌렀을 때의 음식 목록 (변경사항 확인용)
  bool _isSelectionMode = false; // 여러 개 선택 모드 여부
  Set<int> _selectedIndices = {}; // 선택된 음식 인덱스들

  @override
  void initState() {
    super.initState();
    if (widget.existingFoods != null && widget.existingFoods!.isNotEmpty) {
      _foodItems.addAll(widget.existingFoods!);
      _currentStep = _AnalysisStep.reviewFoods;
      debugPrint('✅ [AnalysisScreen] 편집 모드: 기존 음식 ${_foodItems.length}개 로드');
      // 편집 모드에서 초기 로드 시점의 음식 목록도 저장 (분석 시 비교용)
      _analyzedFoods = List<String>.from(widget.existingFoods!);
    }
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  // 두 리스트가 같은지 비교하는 헬퍼 함수 (순서 무관, 중복 고려)
  bool _listEquals(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    // 각 음식의 개수를 세어서 비교
    final map1 = <String, int>{};
    final map2 = <String, int>{};

    for (final item in list1) {
      map1[item] = (map1[item] ?? 0) + 1;
    }
    for (final item in list2) {
      map2[item] = (map2[item] ?? 0) + 1;
    }

    if (map1.length != map2.length) return false;

    for (final entry in map1.entries) {
      if (map2[entry.key] != entry.value) return false;
    }

    return true;
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
            // 여러 이미지를 분석할 수 있도록 기존 음식 목록을 유지하고 새로 탐지된 음식만 추가
            // 편집 모드가 아니고 음식 목록이 비어있을 때만 초기화 (첫 이미지 선택 시)
            if ((widget.existingFoods == null || widget.existingFoods!.isEmpty) && _foodItems.isEmpty) {
              _foodItems.clear();
            }
            // 이미지 분석 결과를 추가 (중복 허용 - 같은 음식도 여러 번 추가 가능)
            if (foods.isNotEmpty) {
              final detectedFoods = foods.map((f) => f['name'] as String).toList();
              debugPrint('🔄 [AnalysisScreen] 새로 탐지된 음식: ${detectedFoods.join(", ")}');
              debugPrint('   기존 음식 목록: ${_foodItems.join(", ")}');
              
              // 중복 허용하여 모두 추가 (같은 음식을 여러 번 먹었을 수 있으므로)
              final beforeCount = _foodItems.length;
              _foodItems.addAll(detectedFoods);
              final addedCount = _foodItems.length - beforeCount;
              debugPrint('   추가된 음식: $addedCount개, 총 음식 수: ${_foodItems.length}개');
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
      // 음식이 추가되면 reviewFoods 단계로 변경하여 분석하기/저장하기 버튼 표시
      if (_currentStep == _AnalysisStep.capture) {
        _currentStep = _AnalysisStep.reviewFoods;
      }
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
    if (index < 0 || index >= _foodItems.length) {
      debugPrint('⚠️ [AnalysisScreen] 잘못된 인덱스: $index (음식 개수: ${_foodItems.length})');
      return;
    }

    final foodToDelete = _foodItems[index];
    debugPrint('🔄 [AnalysisScreen] 삭제 다이얼로그 표시: $foodToDelete (인덱스: $index)');

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _ConfirmDialog(
          target: foodToDelete,
        );
      },
    );

    if (shouldDelete == true) {
      debugPrint('✅ [AnalysisScreen] 음식 삭제 확인: $foodToDelete');
      setState(() {
        if (index < _foodItems.length) {
          _foodItems.removeAt(index);
          debugPrint('✅ [AnalysisScreen] UI에서 음식 삭제 완료. 남은 음식: ${_foodItems.join(", ")}');
        } else {
          debugPrint('⚠️ [AnalysisScreen] 인덱스 범위 초과: $index >= ${_foodItems.length}');
        }
      });
    } else {
      debugPrint('❌ [AnalysisScreen] 삭제 취소됨');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIndices.clear(); // 선택 모드 종료 시 선택 해제
      }
    });
  }

  void _toggleFoodSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _deleteSelectedFoods() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제할 음식을 선택해주세요.')),
      );
      return;
    }

    final selectedFoods = _selectedIndices.map((i) => _foodItems[i]).toList();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _MultiDeleteDialog(
          targets: selectedFoods,
        );
      },
    );

    if (shouldDelete == true) {
      debugPrint('✅ [AnalysisScreen] 여러 음식 삭제 확인: ${selectedFoods.join(", ")}');
      setState(() {
        // 인덱스를 내림차순으로 정렬하여 뒤에서부터 삭제 (인덱스 변경 방지)
        final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
        debugPrint('🔄 [AnalysisScreen] 삭제할 인덱스: $sortedIndices');
        for (final index in sortedIndices) {
          if (index >= 0 && index < _foodItems.length) {
            final deletedFood = _foodItems[index];
            _foodItems.removeAt(index);
            debugPrint('   ✅ 삭제됨: $deletedFood (인덱스: $index)');
          } else {
            debugPrint('   ⚠️ 잘못된 인덱스: $index (음식 개수: ${_foodItems.length})');
          }
        }
        _selectedIndices.clear();
        _isSelectionMode = false;
        debugPrint('✅ [AnalysisScreen] UI에서 여러 음식 삭제 완료. 남은 음식: ${_foodItems.join(", ")}');
      });
    } else {
      debugPrint('❌ [AnalysisScreen] 여러 음식 삭제 취소됨');
    }
  }

  /// 분석만 수행 (DB 변경 없음, 페이지 닫지 않음)
  /// 주의: 현재 백엔드 API 구조상 분석과 저장이 함께 이루어지므로,
  /// 분석하기 버튼을 눌러도 DB에 저장이 됩니다.
  /// 분석 전용 API가 추가되면 이 함수를 수정해야 합니다.
  Future<void> _analyzeOnly() async {
    if (_foodItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('분석할 음식이 없습니다.')),
        );
      }
      return;
    }

    setState(() {
      _currentStep = _AnalysisStep.nutrientAnalysis;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

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

      final mealApiService = MealApiService.instance;

      // 편집 모드에서 분석하기를 누른 경우, 새로 추가된 음식만 분석
      final hasExistingFoods = widget.existingFoods != null && widget.existingFoods!.isNotEmpty;
      final baseFoodsForComparison = _hasAnalyzedOnce
          ? _analyzedFoods
          : (hasExistingFoods ? widget.existingFoods! : <String>[]);

      // 새로 추가된 음식만 추출 (기존 음식 제외)
      final newFoods = _foodItems.where((food) => !baseFoodsForComparison.contains(food)).toList();

      debugPrint('🔄 [AnalysisScreen] 분석만 수행');
      debugPrint('   기존 음식: ${baseFoodsForComparison.join(", ")}');
      debugPrint('   현재 음식: ${_foodItems.join(", ")}');
      debugPrint('   새로 추가된 음식: ${newFoods.join(", ")}');

      // 새로 추가된 음식이 없으면 분석할 필요 없음
      if (newFoods.isEmpty && hasExistingFoods) {
        debugPrint('⚠️ [AnalysisScreen] 새로 추가된 음식이 없음 - 분석하지 않음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('새로 추가된 음식이 없습니다.')),
          );
          setState(() {
            _currentStep = _AnalysisStep.reviewFoods;
          });
        }
        return;
      }

      // 편집 모드에서는 updateMealFoods를 사용 (이미 분석된 음식 재사용)
      // 신규 모드에서는 saveMeal을 사용
      Map<String, dynamic> result;

      if (hasExistingFoods) {
        // 편집 모드: updateMealFoods 사용 (백엔드에서 이미 분석된 음식 재사용, 새로 추가된 음식만 분석)
        debugPrint('🔄 [AnalysisScreen] 편집 모드 - updateMealFoods 사용');
        debugPrint('   전체 음식 목록: ${_foodItems.join(", ")}');
        debugPrint('   새로 추가된 음식: ${newFoods.join(", ")}');
        debugPrint('   ⚠️ 백엔드에서 이미 분석된 음식은 재사용하고, 새로 추가된 음식만 분석해야 함');

        // 전체 음식 목록을 전달 (백엔드에서 이미 분석된 음식은 재사용)
        result = await mealApiService.updateMealFoods(
          memberId: user.uid,
          date: mealDateStr,
          mealTime: mealTime,
          foods: _foodItems,
        );
      } else {
        // 신규 모드: saveMeal 사용
        debugPrint('🔄 [AnalysisScreen] 신규 모드 - saveMeal 사용');
        debugPrint('   분석할 음식: ${_foodItems.join(", ")}');

        final foodsForApi = _foodItems
            .map(
              (name) => {
                'name': name,
                'confidence': 0.9,
              },
            )
            .toList();

        result = await mealApiService.saveMeal(
          memberId: user.uid,
          mealTime: mealTime,
          mealDate: mealDateStr,
          imageId: _savedImageId,
          memo: _foodItems.join(', '),
          foods: foodsForApi,
        );
      }

      debugPrint('✅ [AnalysisScreen] 분석 완료');
      debugPrint('   total_nutrition: ${result['total_nutrition']}');
      debugPrint('   ⚠️ 주의: saveMeal API가 분석과 저장을 함께 수행하므로 DB에 이미 저장됨');

      // 분석 결과를 임시 저장 (저장하기 버튼에서 사용)
      if (mounted) {
        setState(() {
          _analysisResult = result;
          _currentStep = _AnalysisStep.reviewFoods;
          _hasAnalyzedOnce = true; // 분석(저장)이 완료되었음을 표시
          _analyzedFoods = List<String>.from(_foodItems); // 분석 시점의 음식 목록 저장
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('분석이 완료되었습니다. (이미 DB에 저장됨)')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AnalysisScreen] 분석 실패: $e');
      debugPrint('   스택 트레이스: $stackTrace');

      if (mounted) {
        String errorMessage = '분석 중 오류가 발생했습니다.';
        if (e.toString().contains('연결') || e.toString().contains('서버') || e.toString().contains('Socket')) {
          errorMessage = '서버에 연결할 수 없습니다.\n서버가 실행 중인지 확인해주세요.';
        } else {
          final errorStr = e.toString();
          errorMessage = '분석 중 오류가 발생했습니다.\n${errorStr.length > 100 ? errorStr.substring(0, 100) + "..." : errorStr}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 7),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _currentStep = _AnalysisStep.reviewFoods;
          _hasAnalyzedOnce = false; // 에러 발생 시 플래그 리셋
        });
      }
    }
  }

  /// 저장만 수행 (현재 _foodItems 상태를 기준으로 DB에 반영)
  Future<void> _saveOnly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
      }
      return;
    }

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

    final mealApiService = MealApiService.instance;

    // 편집 모드 여부 확인
    // existingFoods가 null이 아니면 편집 모드 (빈 리스트여도 편집 모드)
    // 또는 분석하기 버튼을 눌렀다면 이미 DB에 저장되어 있으므로 편집 모드로 간주
    final hasExistingFoods = widget.existingFoods != null && widget.existingFoods!.isNotEmpty;
    final isEditMode = hasExistingFoods || _hasAnalyzedOnce;

    // 신규 저장 모드에서 음식이 비어있으면 저장할 것이 없음
    if (_foodItems.isEmpty && !isEditMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장할 음식이 없습니다.')),
        );
      }
      return;
    }

    setState(() {
      _currentStep = _AnalysisStep.deleting; // 저장/삭제 중 상태 표시
      if (_foodItems.isNotEmpty) {
        _savingFoods = List<String>.from(_foodItems); // 저장할 음식 목록 설정
        _isDeleting = false; // 저장 중이므로 삭제 중 아님
      }
    });

    try {
      // 기존 음식 목록: widget.existingFoods가 있으면 그것을 사용, 없으면 분석하기로 저장된 경우 현재 _foodItems를 기준으로 비교
      // 하지만 분석하기로 저장된 경우에는 저장 시점의 _foodItems를 알 수 없으므로,
      // _hasAnalyzedOnce가 true이고 widget.existingFoods가 null이면 변경사항을 감지할 수 없음
      // 따라서 분석하기 후에는 무조건 업데이트로 처리
      final existingFoods = widget.existingFoods != null ? List<String>.from(widget.existingFoods!) : <String>[];

      debugPrint('🔄 [AnalysisScreen] 저장만 수행');
      debugPrint('   widget.existingFoods: ${widget.existingFoods}');
      debugPrint('   hasExistingFoods: $hasExistingFoods');
      debugPrint('   _hasAnalyzedOnce: $_hasAnalyzedOnce');
      debugPrint('   isEditMode: $isEditMode');
      debugPrint('   기존 음식: ${existingFoods.join(", ")} (개수: ${existingFoods.length})');
      debugPrint('   현재 음식: ${_foodItems.join(", ")} (개수: ${_foodItems.length})');

      // 삭제할 음식 목록 계산은 나중에 비교 기준 음식 목록을 기준으로 계산

      // 음식 목록이 비어있으면 DB에서 삭제
      if (_foodItems.isEmpty) {
        debugPrint('⚠️ [AnalysisScreen] 음식 목록이 비어있어 DB에서 삭제');

        // 삭제 중인 음식 목록 설정
        // 분석하기로 저장된 경우 현재 _foodItems가 비어있으므로 삭제할 음식이 없음
        // 편집 모드에서 기존 음식이 있었던 경우에만 삭제할 음식 목록 표시
        setState(() {
          _isDeleting = true; // 삭제 중
          _savingFoods.clear(); // 저장할 음식 없음
          if (isEditMode && existingFoods.isNotEmpty) {
            _deletingFoods = List<String>.from(existingFoods);
          } else if (_hasAnalyzedOnce) {
            // 분석하기로 저장된 경우 삭제할 음식 목록을 알 수 없음
            _deletingFoods = <String>[];
          } else {
            _deletingFoods = <String>[];
          }
        });

        // 편집 모드이거나 분석하기로 저장된 경우 삭제
        if (isEditMode || _hasAnalyzedOnce) {
          debugPrint('🔄 [AnalysisScreen] 모든 음식 삭제 API 호출');
          debugPrint('   삭제할 음식: ${existingFoods.join(", ")}');
          debugPrint('   이 API는 해당 날짜($mealDateStr)와 식사 타입($mealTime)의 모든 meal을 삭제합니다.');
          debugPrint('   meal이 삭제되면 해당 meal의 영양소도 함께 삭제되어야 합니다.');

          final deleteResult = await mealApiService.deleteMealsByDateAndType(
            memberId: user.uid,
            date: mealDateStr,
            mealTime: mealTime,
          );

          debugPrint('✅ [AnalysisScreen] 모든 음식 삭제 완료');
          debugPrint('   삭제 결과: $deleteResult');
          debugPrint('   삭제된 meal 개수: ${deleteResult['deleted_count'] ?? 'N/A'}');
        } else if (isEditMode && existingFoods.isEmpty) {
          debugPrint('⚠️ [AnalysisScreen] 편집 모드이지만 기존 음식이 없음 - 삭제할 것이 없음');
        }

        if (mounted) {
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 음식이 삭제되었습니다.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // 분석하기로 저장된 경우 먼저 처리 (별도 로직)
      // 단, 편집 모드(hasExistingFoods)가 아닐 때만 처리
      // 편집 모드에서는 아래의 hasExistingFoods && foodsChanged 케이스에서 처리
      if (_hasAnalyzedOnce && !hasExistingFoods) {
        debugPrint('🔄 [AnalysisScreen] 분석하기로 저장된 meal 처리');
        debugPrint('   분석 시점 음식: ${_analyzedFoods.join(", ")}');
        debugPrint('   현재 음식 목록: ${_foodItems.join(", ")}');
        debugPrint('   분석 결과 존재: ${_analysisResult != null}');

        // 음식 목록이 비어있으면 삭제
        if (_foodItems.isEmpty) {
          debugPrint('🔄 [AnalysisScreen] 분석하기로 저장된 meal 삭제');
          setState(() {
            _isDeleting = true; // 삭제 중
            _savingFoods.clear(); // 저장할 음식 없음
            _deletingFoods = List<String>.from(_analyzedFoods); // 삭제할 음식 목록
          });

          await mealApiService.deleteMealsByDateAndType(
            memberId: user.uid,
            date: mealDateStr,
            mealTime: mealTime,
          );

          if (mounted) {
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

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('모든 음식이 삭제되었습니다.')),
            );
            Navigator.pop(context);
          }
          return;
        }

        // 음식 목록이 변경되었는지 확인
        final foodsChanged = _analyzedFoods.length != _foodItems.length || !_listEquals(_analyzedFoods, _foodItems);

        // 저장하기를 눌렀으면 변경사항이 없어도 무조건 저장 (영양소 정보를 보기 위해)
        debugPrint('🔄 [AnalysisScreen] 분석하기로 저장된 meal 처리 - 저장하기 버튼 클릭');
        debugPrint('   변경사항 여부: $foodsChanged');
        if (!foodsChanged) {
          debugPrint('   변경사항은 없지만 저장하기를 눌렀으므로 저장 진행');
        } else {
          debugPrint('   변경사항이 있으므로 업데이트 진행');
        }

        // 저장 중 상태 설정
        setState(() {
          _isDeleting = false; // 저장 중
          _savingFoods = List<String>.from(_foodItems); // 저장할 음식 목록
          _deletingFoods.clear(); // 삭제할 음식 없음
        });

        // updateMealFoods를 호출하여 최신 영양소 정보를 가져옴
        final result = await mealApiService.updateMealFoods(
          memberId: user.uid,
          date: mealDateStr,
          mealTime: mealTime,
          foods: _foodItems,
        );

        debugPrint('✅ [AnalysisScreen] updateMealFoods 완료');
        debugPrint('   결과: $result');
        debugPrint('   ⚠️ 백엔드에서 이미 분석된 음식은 재사용하고, 새로 추가된 음식만 분석해야 합니다.');

        if (mounted) {
          // 저장된 결과를 콜백으로 전달
          if (widget.onAnalysisComplete != null) {
            widget.onAnalysisComplete!({
              'imageUrl': _uploadedImageUrl,
              'menuText': _foodItems.join(', '),
              'mealType': widget.mealType ?? '점심',
              'selectedDate': mealDate,
              'foods': _foodItems,
              'total_nutrition': result['total_nutrition'] as Map<String, dynamic>? ?? <String, dynamic>{},
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장되었습니다.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // 기존 편집 모드에서 음식 목록이 변경된 경우
      // 주의: _hasAnalyzedOnce && !hasExistingFoods 케이스는 위에서 이미 처리했으므로,
      // 여기서는 편집 모드(hasExistingFoods)인 경우만 처리

      // 편집 모드에서 분석하기를 눌렀다면, 분석 시점의 음식 목록(_analyzedFoods)과 비교
      // 분석하기를 누르지 않았다면, 초기 로드 시점의 음식 목록(existingFoods)과 비교
      final baseFoodsForComparison = _hasAnalyzedOnce ? _analyzedFoods : existingFoods;
      final foodsChanged = hasExistingFoods
          ? (baseFoodsForComparison.length != _foodItems.length || !_listEquals(baseFoodsForComparison, _foodItems))
          : false;

      debugPrint('🔍 [AnalysisScreen] 변경사항 확인');
      debugPrint('   isEditMode: $isEditMode');
      debugPrint('   hasExistingFoods: $hasExistingFoods');
      debugPrint('   _hasAnalyzedOnce: $_hasAnalyzedOnce');
      debugPrint('   foodsChanged: $foodsChanged');
      debugPrint('   비교 기준 음식: ${baseFoodsForComparison.join(", ")} (개수: ${baseFoodsForComparison.length})');
      debugPrint('   현재 음식: ${_foodItems.join(", ")} (개수: ${_foodItems.length})');
      if (hasExistingFoods) {
        debugPrint('   _listEquals 결과: ${_listEquals(baseFoodsForComparison, _foodItems)}');
        debugPrint(
          '   길이 비교: ${baseFoodsForComparison.length} != ${_foodItems.length} = ${baseFoodsForComparison.length != _foodItems.length}',
        );
      }

      // 편집 모드이고 음식 목록이 변경된 경우 (삭제 또는 추가)
      // 주의: _hasAnalyzedOnce && !hasExistingFoods 케이스는 위에서 이미 처리했으므로,
      // 여기서는 hasExistingFoods가 true인 경우만 처리 (중복 방지)
      if (hasExistingFoods && foodsChanged) {
        debugPrint('✅ [AnalysisScreen] 변경사항 감지됨 - 업데이트 진행');
        // updateMealFoods API로 업데이트
        debugPrint('🔄 [AnalysisScreen] 기존 기록 업데이트');

        // 삭제할 음식 목록 계산 (비교 기준 음식 목록에서 현재 음식 목록에 없는 것)
        final actualDeletedFoods = baseFoodsForComparison.where((food) => !_foodItems.contains(food)).toList();
        debugPrint('   비교 기준 음식: ${baseFoodsForComparison.join(", ")}');
        debugPrint('   삭제할 음식: ${actualDeletedFoods.join(", ")}');
        debugPrint('   남은 음식: ${_foodItems.join(", ")}');

        // 삭제 중인 음식 목록 설정
        setState(() {
          _isDeleting = actualDeletedFoods.isNotEmpty; // 삭제할 음식이 있으면 삭제 중, 없으면 저장 중
          if (_isDeleting) {
            _deletingFoods = actualDeletedFoods;
            _savingFoods.clear();
          } else {
            _savingFoods = List<String>.from(_foodItems);
            _deletingFoods.clear();
          }
        });

        debugPrint('🔄 [AnalysisScreen] updateMealFoods API 호출');
        debugPrint('   이 API는 기존 meal의 음식 목록을 새로운 목록으로 교체합니다.');
        debugPrint('   백엔드에서 삭제된 음식의 영양소를 제거하고 남은 음식의 영양소만 재계산해야 합니다.');

        final result = await mealApiService.updateMealFoods(
          memberId: user.uid,
          date: mealDateStr,
          mealTime: mealTime,
          foods: _foodItems, // 남은 음식 목록만 전달 (삭제된 음식은 제외)
        );

        debugPrint('✅ [AnalysisScreen] updateMealFoods 완료');
        debugPrint('   결과: $result');
        debugPrint('   반환된 total_nutrition: ${result['total_nutrition']}');
        debugPrint('   ⚠️ 백엔드에서 삭제된 음식의 영양소가 제거되고 남은 음식의 영양소만 포함되어야 합니다.');
        debugPrint('   ⚠️ 백엔드에서 이미 분석된 음식은 재사용하고, 새로 추가된 음식만 분석해야 합니다.');

        if (mounted) {
          // 편집 모드에서는 onAnalysisComplete 콜백을 호출하지 않음
          // (이미 DB에 저장되었고, 중복 저장 방지)
          // 대신 리포트 화면이 자동으로 새로고침되도록 Navigator.pop만 수행
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('변경사항이 저장되었습니다.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // 변경사항이 없는 경우에도 저장하기를 눌렀으면 저장 (영양소 정보를 보기 위해)
      if (hasExistingFoods && !foodsChanged) {
        debugPrint('✅ [AnalysisScreen] 편집 모드이고 변경사항이 없지만 저장하기를 눌렀으므로 저장 진행');
        
        // 저장 중 상태 설정
        setState(() {
          _isDeleting = false; // 저장 중
          _savingFoods = List<String>.from(_foodItems); // 저장할 음식 목록
          _deletingFoods.clear(); // 삭제할 음식 없음
        });
        
        // updateMealFoods를 호출하여 영양소 정보를 다시 가져옴
        final result = await mealApiService.updateMealFoods(
          memberId: user.uid,
          date: mealDateStr,
          mealTime: mealTime,
          foods: _foodItems,
        );

        debugPrint('✅ [AnalysisScreen] updateMealFoods 완료 (변경사항 없지만 저장 완료)');
        debugPrint('   결과: $result');

        if (mounted) {
          // 영양소 정보를 콜백으로 전달하여 리포트 화면에서 볼 수 있도록 함
          if (widget.onAnalysisComplete != null) {
            widget.onAnalysisComplete!({
              'imageUrl': _uploadedImageUrl,
              'menuText': _foodItems.join(', '),
              'mealType': widget.mealType ?? '점심',
              'selectedDate': mealDate,
              'foods': _foodItems,
              'total_nutrition': result['total_nutrition'] as Map<String, dynamic>? ?? <String, dynamic>{},
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장되었습니다.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // 신규 저장 (편집 모드도 아니고 분석하기도 안 눌렀음)
      if (!hasExistingFoods && !_hasAnalyzedOnce) {
        debugPrint('🔄 [AnalysisScreen] 신규 기록 저장');

        // 저장 중 상태 유지 (이미 위에서 설정됨)
        setState(() {
          _isDeleting = false; // 저장 중
          _savingFoods = List<String>.from(_foodItems); // 저장할 음식 목록
          _deletingFoods.clear(); // 삭제할 음식 없음
        });

        final foodsForApi = _foodItems
            .map(
              (name) => {
                'name': name,
                'confidence': 0.9,
              },
            )
            .toList();

        final result = await mealApiService.saveMeal(
          memberId: user.uid,
          mealTime: mealTime,
          mealDate: mealDateStr,
          imageId: _savedImageId,
          memo: _foodItems.join(', '),
          foods: foodsForApi,
        );

        if (mounted) {
          if (widget.onAnalysisComplete != null) {
            widget.onAnalysisComplete!({
              'imageUrl': _uploadedImageUrl,
              'menuText': _foodItems.join(', '),
              'mealType': widget.mealType ?? '점심',
              'selectedDate': mealDate,
              'foods': _foodItems,
              'total_nutrition': result['total_nutrition'] as Map<String, dynamic>? ?? <String, dynamic>{},
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장되었습니다.')),
          );
          Navigator.pop(context);
        }
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AnalysisScreen] 저장 실패: $e');
      debugPrint('   스택 트레이스: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 7),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _currentStep = _AnalysisStep.reviewFoods;
          _deletingFoods.clear(); // 삭제 중 목록 초기화
          _savingFoods.clear(); // 저장 중 목록 초기화
          _isDeleting = false; // 상태 초기화
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '추가된 음식',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          if (_isSelectionMode && _selectedIndices.isNotEmpty)
                            TextButton.icon(
                              onPressed: _deleteSelectedFoods,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text('선택 삭제 (${_selectedIndices.length})'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          TextButton.icon(
                            onPressed: _toggleSelectionMode,
                            icon: Icon(_isSelectionMode ? Icons.check_circle : Icons.check_circle_outline, size: 18),
                            label: Text(_isSelectionMode ? '선택 취소' : '선택 모드'),
                            style: TextButton.styleFrom(
                              foregroundColor: ColorPalette.primary200,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFoodList(),
              ],
              const SizedBox(height: 24),
              // 분석 중이거나 삭제 중이 아닐 때는 항상 분석하기와 저장하기 버튼 표시
              if (_currentStep != _AnalysisStep.nutrientAnalysis &&
                  _currentStep != _AnalysisStep.deleting &&
                  _currentStep != _AnalysisStep.analyzingImage) ...[
                // 분석하기와 저장하기 버튼을 나란히 배치
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyzeButton(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSaveButton(),
                    ),
                  ],
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
            Text(
              textAlign: TextAlign.center,
              _foodItems.isEmpty ? 'AI가 사용자의 식단을 분석하고 있습니다.' : '${_foodItems.join(", ")}을(를) 분석하고 있습니다.',
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
              _isDeleting
                  ? (_deletingFoods.isEmpty ? '음식을 삭제 중입니다.' : '${_deletingFoods.join(", ")}을(를) 삭제 중입니다.')
                  : (_savingFoods.isEmpty ? '저장 중입니다.' : '${_savingFoods.join(", ")}을(를) 저장하고 있습니다.'),
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
          final isSelected = _selectedIndices.contains(index);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              onTap: _isSelectionMode ? () => _toggleFoodSelection(index) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? ColorPalette.primary100.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleFoodSelection(index),
                        activeColor: ColorPalette.primary200,
                      ),
                    ] else ...[
                      IconButton(
                        onPressed: () => _showDeleteDialog(index),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? ColorPalette.primary200 : null,
                        ),
                      ),
                    ),
                    if (!_isSelectionMode)
                      IconButton(
                        onPressed: () => _showEditDialog(index),
                        icon: const Icon(Icons.edit, size: 18),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    final isDisabled =
        _currentStep == _AnalysisStep.analyzingImage ||
        _currentStep == _AnalysisStep.nutrientAnalysis ||
        _currentStep == _AnalysisStep.deleting;
    final buttonLabel = _currentStep == _AnalysisStep.nutrientAnalysis
        ? '분석 중...'
        : _currentStep == _AnalysisStep.analyzingImage
        ? '이미지 분석 중...'
        : '분석하기';

    return FilledButton(
      onPressed: isDisabled
          ? null
          : () {
              _analyzeOnly();
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
    );
  }

  Widget _buildSaveButton() {
    final isDisabled =
        _currentStep == _AnalysisStep.analyzingImage ||
        _currentStep == _AnalysisStep.nutrientAnalysis ||
        _currentStep == _AnalysisStep.deleting;
    final buttonLabel = _currentStep == _AnalysisStep.deleting ? '저장 중...' : '저장하기';

    return OutlinedButton(
      onPressed: isDisabled
          ? null
          : () {
              _saveOnly();
            },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: ColorPalette.primary200, width: 2),
        foregroundColor: ColorPalette.primary200,
      ),
      child: Text(
        buttonLabel,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
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

class _MultiDeleteDialog extends StatelessWidget {
  const _MultiDeleteDialog({required this.targets});

  final List<String> targets;

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
              '${targets.length}개의 음식을 삭제하시겠어요?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: targets.map((target) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• $target',
                        style: const TextStyle(
                          fontSize: 14,
                          color: ColorPalette.text100,
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
