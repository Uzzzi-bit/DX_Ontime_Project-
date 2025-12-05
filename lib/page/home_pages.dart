import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widget/bottom_bar_widget.dart';
import '../widget/home/header_section.dart';
import '../widget/home/nutrient_grid.dart';
import '../widget/home/supplement_checklist.dart';
import '../widget/home/eat_check_section.dart';
import '../widget/home/today_meal_section.dart';
import '../widget/home/rounded_container.dart';
import 'chat_pages.dart';
import 'report_pages.dart';
import 'recipe_pages.dart';
import '../model/user_model.dart';
import '../api/member_api_service.dart';
import '../model/supplement_effects.dart';
import '../model/nutrient_type.dart';
import '../utils/responsive_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _qaController = TextEditingController();
  String? _selectedImagePath; // 선택된 이미지 경로 저장

  // Mom Care Mode 상태
  bool _isMomCareMode = false;
  bool _isLoading = true;
  UserModel? _userData;
  static const String _momCareModeKey = 'isMomCareMode';

  @override
  void initState() {
    super.initState();
    // 기본값으로 초기화
    _nutrientProgress = Map.from(_baseNutrientProgress);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Shared Preferences에서 Mom Care Mode 상태 불러오기
      final prefs = await SharedPreferences.getInstance();
      final isMomCareMode = prefs.getBool(_momCareModeKey) ?? false;

      // Firebase 사용자 정보 가져오기
      final user = FirebaseAuth.instance.currentUser;
      String? userNickname;
      DateTime? userDueDate;
      int? userPregnancyWeek;

      if (user != null) {
        try {
          // Django API에서 사용자 건강 정보 가져오기
          final healthInfo = await MemberApiService.instance.getHealthInfo(user.uid);
          userNickname = healthInfo['nickname'] as String?;
          userPregnancyWeek = healthInfo['pregnancy_week'] as int? ?? healthInfo['pregWeek'] as int?;

          // dueDate 파싱
          final dueDateStr = healthInfo['dueDate'] as String?;
          if (dueDateStr != null) {
            userDueDate = DateTime.parse(dueDateStr);
          }

          debugPrint('✅ [HomeScreen] 사용자 정보 로드: nickname=$userNickname, week=$userPregnancyWeek');
        } catch (e) {
          debugPrint('⚠️ [HomeScreen] 건강 정보 로드 실패 (기본값 사용): $e');
        }
      }

      // UserModel 생성 (실제 데이터 또는 기본값)
      final userData = UserModel(
        nickname: userNickname ?? '사용자',
        pregnancyWeek: userPregnancyWeek ?? 20,
        statusMessage: '건강한 임신 생활을 응원합니다!',
        dueDate: userDueDate ?? DateTime(2026, 7, 1),
      );

      if (mounted) {
        setState(() {
          _isMomCareMode = isMomCareMode;
          _userData = userData;
          _isLoading = false;
        });
        debugPrint('홈 화면 데이터 로드 완료: _isMomCareMode=$isMomCareMode, _userData=${userData.nickname}');
        // report_pages에서 계산된 값으로 업데이트
        _updateNutrientProgress();
      }
    } catch (e) {
      // 에러 발생 시 기본값 사용
      debugPrint('홈 화면 데이터 로드 에러: $e');
      if (mounted) {
        setState(() {
          _isMomCareMode = false;
          _isLoading = false;
          // 기본 UserModel 생성
          _userData = UserModel(
            nickname: '사용자',
            pregnancyWeek: 20,
            statusMessage: '건강한 임신 생활을 응원합니다!',
            dueDate: DateTime(2026, 7, 1),
          );
        });
      }
    }
  }

  // 사용자 정보 (Django API에서 로드)
  String get _userName => _userData?.nickname ?? '사용자';
  DateTime get _dueDate => _userData?.dueDate ?? DateTime(2026, 7, 1);
  int get _pregnancyWeek => _userData?.pregnancyWeek ?? 20;

  // TODO: [DB] 금일 칼로리 섭취량 및 목표량 GET
  // report_pages.dart에서 계산된 값 사용
  double get _currentCalorie => ReportScreen.getCurrentCalorie();
  double get _targetCalorie => ReportScreen.getTargetCalorie();

  // TODO: [DB] 금일 영양소 섭취 현황 데이터 로드
  // 기본 영양소 섭취량 (0.0 ~ 100.0 퍼센트) - 리포트 페이지/음식 섭취 등으로 채워진 기본값 (영양제 제외)
  // report_pages.dart에서 계산된 비율 값을 가져와서 사용
  Map<NutrientType, double> get _baseNutrientProgress {
    final reportProgress = ReportScreen.getNutrientProgress();
    // report_pages에서 계산된 값이 있으면 사용, 없으면 기본값
    return {
      NutrientType.iron: reportProgress[NutrientType.iron] ?? 0.0,
      NutrientType.vitaminD: reportProgress[NutrientType.vitaminD] ?? 0.0,
      NutrientType.folate: reportProgress[NutrientType.folate] ?? 0.0,
      NutrientType.omega3: reportProgress[NutrientType.omega3] ?? 0.0,
      NutrientType.calcium: reportProgress[NutrientType.calcium] ?? 0.0,
      NutrientType.vitaminB: reportProgress[NutrientType.vitaminB] ?? 0.0,
    };
  }

  // 화면에 보여줄 실제 영양소 섭취량 (기본값 + 영양제 효과 포함)
  late Map<NutrientType, double> _nutrientProgress;

  // 영양제 체크리스트 (6개)
  final List<_SupplementOption> _supplements = const [
    _SupplementOption(
      id: 'iron-pill',
      label: '철분제',
      nutrient: NutrientType.iron,
    ),
    _SupplementOption(
      id: 'calcium',
      label: '칼슘',
      nutrient: NutrientType.calcium,
    ),
    _SupplementOption(
      id: 'vitamin-complex',
      label: '종합영양제',
      nutrient: NutrientType.folate,
    ),
    _SupplementOption(
      id: 'omega3',
      label: '오메가-3',
      nutrient: NutrientType.omega3,
    ),
    _SupplementOption(
      id: 'vitaminD',
      label: '비타민D',
      nutrient: NutrientType.vitaminD,
    ),
    _SupplementOption(
      id: 'vitaminB',
      label: '비타민B',
      nutrient: NutrientType.vitaminB,
    ),
  ];

  // TODO: [SERVER] 추천 레시피 리스트 Fetch
  // 오늘의 추천 식단 - recipe_pages.dart의 레시피 데이터 사용
  //
  // [서버 연동 시 구현 사항]
  // 1. report_pages.dart에서 AI 추천 식단이 변경되면 서버에 업데이트 요청
  // 2. 서버에서 변경된 추천 식단 정보를 받아옴
  // 3. 이 getter가 서버 데이터를 참조하도록 수정
  // 4. report_pages.dart에서 변경 시 홈 화면의 추천 식단이 자동으로 업데이트되도록
  //    - 방법 1: 서버에서 푸시 알림으로 홈 화면에 업데이트 신호 전송
  //    - 방법 2: 홈 화면 진입 시 서버에서 최신 추천 식단 정보 GET
  //    - 방법 3: report_pages.dart에서 변경 후 Navigator.pop() 시 콜백으로 홈 화면 업데이트
  List<_RecommendedMeal> get _recommendedMeals {
    try {
      // recipe_pages.dart에서 레시피 가져오기 (더미 데이터)
      final recipes = RecipeScreen.getRecommendedRecipes();

      // 레시피가 비어있으면 빈 리스트 반환
      if (recipes.isEmpty) {
        debugPrint('경고: 레시피 리스트가 비어있습니다.');
        return [];
      }

      // 레시피를 RecommendedMeal 형식으로 변환
      final List<Color> backgroundColors = [
        const Color(0xFFD2ECBF), // 연어스테이크 색상
        const Color(0xFFFEF493), // 냉모밀 색상
        const Color(0xFFBCE7F0), // 미역국 색상
      ];

      return recipes.asMap().entries.map((entry) {
        final index = entry.key;
        final recipe = entry.value;
        // 레시피 ID 매핑 (기존 매핑 유지)
        String mealId;
        switch (index) {
          case 0:
            mealId = 'salmon-steak'; // 간장 닭봉 구이
            break;
          case 1:
            mealId = 'cold-noodles'; // 냉메밀
            break;
          case 2:
            mealId = 'seaweed-soup'; // 미역국
            break;
          default:
            mealId = 'salmon-steak';
        }

        return _RecommendedMeal(
          id: mealId,
          name: recipe.title,
          imagePath: recipe.imagePath,
          calories: recipe.calories,
          tags: recipe.tags,
          backgroundColor: backgroundColors[index % backgroundColors.length],
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('에러: _recommendedMeals getter에서 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      // 에러 발생 시 빈 리스트 반환 (빈 화면 대신 기본 데이터 표시)
      return [];
    }
  }

  final List<_ApplianceInfo> _appliances = const [
    _ApplianceInfo(
      name: '광파오븐',
      assetPath: 'assets/image/oven.png',
    ),
    _ApplianceInfo(
      name: '냉장고',
      assetPath: 'assets/image/fridge.png',
    ),
  ];

  // 영양제 선택 상태 (id 기반)
  Set<String> _selectedSupplementIds = {};

  // SupplementChecklist에 전달할 영양제 id 리스트
  List<String> get _supplementIds => _supplements.map((s) => s.id).toList();

  List<Map<String, dynamic>> get _nutrientData {
    try {
      // 데이터가 없을 경우 임시 데이터 반환
      if (_nutrientProgress.isEmpty) {
        debugPrint('홈 화면: _nutrientProgress가 비어있습니다. 기본값 사용');
        return [
          {'label': '철분', 'progress': 0.0},
          {'label': '비타민D', 'progress': 0.0},
          {'label': '엽산', 'progress': 0.0},
          {'label': '오메가-3', 'progress': 0.0},
          {'label': '칼슘', 'progress': 0.0},
          {'label': '비타민B', 'progress': 0.0},
        ];
      }
      return [
        {'label': '철분', 'progress': _nutrientProgress[NutrientType.iron] ?? 0.0},
        {'label': '비타민D', 'progress': _nutrientProgress[NutrientType.vitaminD] ?? 0.0},
        {'label': '엽산', 'progress': _nutrientProgress[NutrientType.folate] ?? 0.0},
        {'label': '오메가-3', 'progress': _nutrientProgress[NutrientType.omega3] ?? 0.0},
        {'label': '칼슘', 'progress': _nutrientProgress[NutrientType.calcium] ?? 0.0},
        {'label': '비타민B', 'progress': _nutrientProgress[NutrientType.vitaminB] ?? 0.0},
      ];
    } catch (e, stackTrace) {
      debugPrint('에러: _nutrientData getter에서 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      // 에러 발생 시 기본값 반환
      return [
        {'label': '철분', 'progress': 0.0},
        {'label': '비타민D', 'progress': 0.0},
        {'label': '엽산', 'progress': 0.0},
        {'label': '오메가-3', 'progress': 0.0},
        {'label': '칼슘', 'progress': 0.0},
        {'label': '비타민B', 'progress': 0.0},
      ];
    }
  }

  List<Map<String, dynamic>> get _mealData {
    try {
      final meals = _recommendedMeals;
      // 데이터가 없을 경우 임시 데이터 반환
      if (meals.isEmpty) {
        debugPrint('홈 화면: _recommendedMeals가 비어있습니다. 기본값 사용');
        return [
          {
            'id': 'temp-1',
            'name': '연어스테이크',
            'imagePath': 'assets/image/sample_food.png',
            'calories': 350,
            'tags': ['오메가-3', '비타민 D'],
            'backgroundColor': const Color(0xFFD2ECBF).value.toInt(),
          },
          {
            'id': 'temp-2',
            'name': '냉모밀',
            'imagePath': 'assets/image/sample_food.png',
            'calories': 400,
            'tags': ['단백질', '미네랄'],
            'backgroundColor': const Color(0xFFFEF493).value.toInt(),
          },
          {
            'id': 'temp-3',
            'name': '미역국',
            'imagePath': 'assets/image/sample_food.png',
            'calories': 150,
            'tags': ['철분', '칼슘'],
            'backgroundColor': const Color(0xFFBCE7F0).value.toInt(),
          },
        ];
      }
      return meals.map((meal) {
        return {
          'id': meal.id,
          'name': meal.name,
          'imagePath': meal.imagePath,
          'calories': meal.calories,
          'tags': meal.tags,
          'backgroundColor': meal.backgroundColor.value.toInt(),
        };
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('에러: _mealData getter에서 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      // 에러 발생 시 기본값 반환
      return [
        {
          'id': 'temp-1',
          'name': '연어스테이크',
          'imagePath': 'assets/image/sample_food.png',
          'calories': 350,
          'tags': ['오메가-3', '비타민 D'],
          'backgroundColor': const Color(0xFFD2ECBF).value.toInt(),
        },
        {
          'id': 'temp-2',
          'name': '냉모밀',
          'imagePath': 'assets/image/sample_food.png',
          'calories': 400,
          'tags': ['단백질', '미네랄'],
          'backgroundColor': const Color(0xFFFEF493).value.toInt(),
        },
        {
          'id': 'temp-3',
          'name': '미역국',
          'imagePath': 'assets/image/sample_food.png',
          'calories': 150,
          'tags': ['철분', '칼슘'],
          'backgroundColor': const Color(0xFFBCE7F0).value.toInt(),
        },
      ];
    }
  }

  // 임신 주차 계산
  int _getPregnancyWeek() {
    return _pregnancyWeek;
  }

  // 임신 진행률 계산 (0.0 ~ 1.0) - 출산예정일까지의 남은 기간 기준
  double _getPregnancyProgress() {
    final currentWeek = _pregnancyWeek;
    const int totalWeeks = 40;
    final double progress = currentWeek / totalWeeks;
    return progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _qaController.dispose();
    super.dispose();
  }

  void _handleAskSubmit() {
    final query = _qaController.text.trim();
    // 텍스트나 이미지 중 하나라도 있어야 전송 가능
    if (query.isEmpty && _selectedImagePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          initialText: query.isEmpty ? null : query,
          initialImagePath: _selectedImagePath,
        ),
      ),
    );

    // 전송 후 상태 초기화
    setState(() {
      _qaController.clear();
      _selectedImagePath = null;
    });
  }

  void _handleImageSelected(XFile file) {
    // 이미지 선택 시 바로 채팅 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          initialText: _qaController.text.trim().isEmpty ? null : _qaController.text.trim(),
          initialImagePath: file.path,
        ),
      ),
    );

    // 전송 후 상태 초기화
    setState(() {
      _qaController.clear();
      _selectedImagePath = null;
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }

  /// 플로팅 버튼 클릭 시 식사 타입 선택 다이얼로그 표시
  void _showMealImagePicker() {
    showDialog(
      context: context,
      barrierDismissible: true, // 외부 클릭 시 닫기
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    '식사 타입 선택',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.wb_sunny, color: Color(0xFF5BB5C8)),
                  title: const Text('아침'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _navigateToMealAnalysis('아침');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lunch_dining, color: Color(0xFF5BB5C8)),
                  title: const Text('점심'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _navigateToMealAnalysis('점심');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cookie, color: Color(0xFF5BB5C8)),
                  title: const Text('간식'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _navigateToMealAnalysis('간식');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dinner_dining, color: Color(0xFF5BB5C8)),
                  title: const Text('저녁'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _navigateToMealAnalysis('저녁');
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 선택한 식사 타입으로 리포트 화면으로 이동하여 식단 분석 시작
  void _navigateToMealAnalysis(String mealType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          initialMealType: mealType,
        ),
      ),
    );
  }

  /// report_pages에서 계산된 영양소 비율로 업데이트
  void _updateNutrientProgress() {
    setState(() {
      _nutrientProgress = Map.from(_baseNutrientProgress);
      // 영양제 효과 반영
      _recalculateNutrientsWithSupplements();
    });
  }

  /// 영양제 효과를 반영하여 영양소 진행도를 재계산합니다.
  ///
  /// 기본값(_baseNutrientProgress)에 선택된 영양제들의 효과를 누적하여
  /// 최종 _nutrientProgress를 계산합니다.
  void _recalculateNutrientsWithSupplements() {
    // 기본값으로 초기화
    _nutrientProgress = Map.from(_baseNutrientProgress);

    // 선택된 영양제마다 효과 누적
    for (final id in _selectedSupplementIds) {
      final effects = SupplementEffects.effects[id];
      if (effects == null) continue;

      effects.forEach((nutrient, delta) {
        final current = _nutrientProgress[nutrient] ?? 0.0;
        final updated = (current + delta).clamp(0.0, 100.0);
        _nutrientProgress[nutrient] = updated;
      });
    }
  }

  /// 영양제 체크/해제 토글 함수
  ///
  /// [supplementId] 영양제 id (예: 'iron-pill', 'calcium')
  void _toggleSupplement(String supplementId) {
    setState(() {
      if (_selectedSupplementIds.contains(supplementId)) {
        _selectedSupplementIds.remove(supplementId);
      } else {
        _selectedSupplementIds.add(supplementId);
      }
      // 영양소 진행도 재계산
      _recalculateNutrientsWithSupplements();
    });
    // TODO: [API] 영양제 체크 상태 POST/PUT 요청
  }

  void _navigateToRecipe(String mealId) {
    // TODO: [API] 실제 레시피 상세 페이지로 이동
    // 홈 화면의 추천 식단과 recipe_pages의 메뉴 매핑
    // 연어스테이크 → 간장 닭봉 구이 (index 0)
    // 냉모밀 → 냉메밀 (index 1)
    // 미역국 → 미역국 (index 2)
    int recipeIndex = 0;
    switch (mealId) {
      case 'salmon-steak':
        recipeIndex = 0; // 간장 닭봉 구이
        break;
      case 'cold-noodles':
        recipeIndex = 1; // 냉메밀
        break;
      case 'seaweed-soup':
        recipeIndex = 2; // 미역국
        break;
      default:
        recipeIndex = 0;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeScreen(
          initialMenuIndex: recipeIndex,
        ),
      ),
    );
  }

  // Mode OFF 화면 빌드
  Widget _buildModeOffView() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // 즐겨 찾는 제품 목록
    final List<Map<String, String>> favoriteProducts = const [
      {'name': '광파오븐', 'icon': 'assets/image/oven2.png'},
      {'name': '공기청정기', 'icon': 'assets/image/air_purifier.png'},
      {'name': '세탁기', 'icon': 'assets/image/washing_machine.png'},
      {'name': '환기', 'icon': 'assets/image/circulator.png'},
      {'name': '에어컨', 'icon': 'assets/image/air_conditioner.png'},
      {'name': '로봇청소기', 'icon': 'assets/image/robot.png'},
    ];

    // 스마트 루틴 목록
    final List<Map<String, String>> smartRoutines = const [
      {'name': '🏠 집에 가는길', 'icon': ''},
      {'name': '🎥 무비 타임에는', 'icon': ''},
      {'name': '🌙 잠들기 전', 'icon': ''},
      {'name': '🧳 휴가', 'icon': ''},
    ];

    return Container(
      color: const Color(0xFFBCE7F0),
      height: double.infinity, // 피그마 배경색
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 타이틀
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_userName}님',
                      style:
                          textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ) ??
                          const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '홈',
                      style:
                          textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ) ??
                          const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
              ),

              // 3D 홈뷰 만들기 배너
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.all(10),
                      width: ResponsiveHelper.width(context, 0.16),
                      height: ResponsiveHelper.width(context, 0.16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage('assets/image/blueprint.png'),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.width(context, 0.021)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3D 홈뷰로 우리집과 제품의 실시간 상태를\n한눈에 확인 해보세요.',
                            style:
                                textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black,
                                  letterSpacing: 0.14,
                                  height: 1.43,
                                ) ??
                                const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  letterSpacing: 0.14,
                                  height: 1.43,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5DBFF),
                              borderRadius: BorderRadius.circular(1000),
                            ),
                            child: Text(
                              '3D 홈뷰 만들기',
                              style:
                                  textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: const Color(0xFF4A57BF),
                                    letterSpacing: 0.1,
                                  ) ??
                                  const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF4A57BF),
                                    letterSpacing: 0.1,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 즐겨 찾는 제품 섹션
              Text(
                '즐겨 찾는 제품',
                style:
                    textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: const Color(0xFF606C80),
                      letterSpacing: 0.5,
                    ) ??
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF606C80),
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: favoriteProducts.length,
                itemBuilder: (context, index) {
                  final product = favoriteProducts[index];
                  final iconPath = product['icon'];

                  return Container(
                    margin: EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.037)),
                          ),
                          child: Center(
                            child: iconPath != null && iconPath.isNotEmpty
                                ? Image.asset(
                                    iconPath,
                                    width: ResponsiveHelper.width(context, 0.16),
                                    height: ResponsiveHelper.width(context, 0.16),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox.shrink();
                                    },
                                  )
                                : SizedBox(height: 10),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.height(context, 0.01)),
                        Expanded(
                          child: Text(
                            product['name'] ?? '',
                            style:
                                textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black,
                                  letterSpacing: 0.5,
                                ) ??
                                const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  letterSpacing: 0.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // 스마트 루틴 섹션
              Text(
                '스마트 루틴',
                style:
                    textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: const Color(0xFF606C80),
                      letterSpacing: 0.5,
                    ) ??
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF606C80),
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 165 / 50,
                ),
                itemCount: smartRoutines.length,
                itemBuilder: (context, index) {
                  final routine = smartRoutines[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        routine['name'] ?? '',
                        style:
                            textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ) ??
                            const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 100), // 하단 네비게이션 바 공간
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중일 때
    if (_isLoading) {
      debugPrint('홈 화면: 로딩 중...');
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
        bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
      );
    }

    debugPrint('홈 화면 빌드: _isMomCareMode=$_isMomCareMode, _userData=${_userData?.nickname}');

    // Mom Care Mode가 OFF일 때
    if (!_isMomCareMode) {
      debugPrint('홈 화면: 맘케어 모드 OFF - Mode Off 화면 표시');
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildModeOffView(),
        bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
      );
    }

    // Mom Care Mode가 ON일 때 - 기존 대시보드
    debugPrint('홈 화면: 맘케어 모드 ON - 대시보드 화면 표시 시작');
    try {
      debugPrint('홈 화면: try 블록 시작');
      final theme = Theme.of(context);
      final textTheme = theme.textTheme;
      final now = DateTime.now();
      final dateFormat = DateFormat('M월 d일 (E)', 'ko');
      debugPrint('홈 화면: 날짜 포맷 준비 완료');

      final pregnancyWeek = _getPregnancyWeek();
      final pregnancyProgress = _getPregnancyProgress();
      debugPrint('홈 화면: 임신 주차 계산 완료 - pregnancyWeek=$pregnancyWeek, progress=$pregnancyProgress');

      // 데이터 getter 테스트
      debugPrint('홈 화면: _nutrientData 테스트 시작');
      final nutrientData = _nutrientData;
      debugPrint('홈 화면: _nutrientData 완료 - ${nutrientData.length}개');

      debugPrint('홈 화면: _mealData 테스트 시작');
      final mealData = _mealData;
      debugPrint('홈 화면: _mealData 완료 - ${mealData.length}개');

      debugPrint('홈 화면: 모든 데이터 준비 완료, Scaffold 빌드 시작');

      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 80, // 하단 네비게이션 바 + SafeArea 공간
            ),
            child: Column(
              children: [
                /// 1) 파란색 헤더
                HeaderSection(
                  userName: _userName,
                  pregnancyWeek: pregnancyWeek,
                  dueDate: _dueDate,
                  pregnancyProgress: pregnancyProgress,
                  onHealthInfoUpdate: () => Navigator.pushNamed(context, '/healthinfo'),
                ),

                /// 2) RoundedContainer를 자연스럽게 위로 끌어올림
                Transform.translate(
                  offset: Offset(0, -ResponsiveHelper.height(context, 0.26)), // 흰색 박스 배경 침투 조절
                  child: RoundedContainer(
                    child: Padding(
                      padding: ResponsiveHelper.padding(context, all: 20.0), // 패딩을 20에서 16으로 줄여 공간 확보
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              SizedBox(height: ResponsiveHelper.height(context, 0.02)),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dateFormat.format(now),
                                      style:
                                          textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: ResponsiveHelper.fontSize(context, 13),
                                            letterSpacing: 0.5,
                                          ) ??
                                          TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, 13),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                    SizedBox(width: ResponsiveHelper.width(context, 0.048)),
                                    Bounceable(
                                      onTap: () {},
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const ReportScreen(),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveHelper.width(context, 0.027),
                                            vertical: ResponsiveHelper.height(context, 0.005),
                                          ),
                                          backgroundColor: const Color(0xFFBCE7F0),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.021)),
                                          ),
                                          foregroundColor: const Color(0xFF49454F),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          '종합리포트 가기',
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, 9),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.042)),
                          _CalorieAndNutrientSection(
                            currentCalorie: _currentCalorie,
                            targetCalorie: _targetCalorie,
                            nutrientData: _nutrientData,
                            textTheme: textTheme,
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.02)),

                          ///여기부터 수정
                          SupplementChecklist(
                            supplements: _supplementIds
                                .map((id) {
                                  try {
                                    return _supplements.firstWhere((s) => s.id == id).label;
                                  } catch (e) {
                                    debugPrint('에러: 영양제 id "$id"를 찾을 수 없습니다: $e');
                                    return '';
                                  }
                                })
                                .where((label) => label.isNotEmpty)
                                .toList(),
                            selectedSupplements: _selectedSupplementIds
                                .map((id) {
                                  try {
                                    return _supplements.firstWhere((s) => s.id == id).label;
                                  } catch (e) {
                                    debugPrint('에러: 선택된 영양제 id "$id"를 찾을 수 없습니다: $e');
                                    return '';
                                  }
                                })
                                .where((label) => label.isNotEmpty)
                                .toSet(),
                            onToggle: (label) {
                              try {
                                final id = _supplements.firstWhere((s) => s.label == label).id;
                                _toggleSupplement(id);
                              } catch (e) {
                                debugPrint('에러: 영양제 label "$label"를 찾을 수 없습니다: $e');
                              }
                            },
                            onAdd: () {
                              // TODO: [API] 영양제 추가하기 기능
                            },
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.01)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.width(context, 0.011)),
                            child: Text(
                              '※ 영양제 효과는 1일 권장량 대비 평균적인 퍼센트로 가정한 값입니다. 실제 제품과는 차이가 있을 수 있어요.',
                              style:
                                  textTheme.bodySmall?.copyWith(
                                    fontSize: ResponsiveHelper.fontSize(context, 9),
                                    fontWeight: FontWeight.w300,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.09,
                                    height: 1.3,
                                  ) ??
                                  TextStyle(
                                    fontSize: ResponsiveHelper.fontSize(context, 9),
                                    fontWeight: FontWeight.w300,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.09,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.04)),
                          EatCheckSection(
                            controller: _qaController,
                            onSubmit: _handleAskSubmit,
                            onImageSelected: _handleImageSelected,
                            selectedImagePath: _selectedImagePath,
                            onRemoveImage: _removeSelectedImage,
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.04)),
                          TodayMealSection(
                            meals: _mealData,
                            onMealTap: _navigateToRecipe,
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.025)),
                          Text(
                            '즐겨 찾는 제품',
                            style:
                                textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: ResponsiveHelper.fontSize(context, 12),
                                  letterSpacing: 0.5,
                                ) ??
                                TextStyle(
                                  fontSize: ResponsiveHelper.fontSize(context, 12),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          SizedBox(height: ResponsiveHelper.height(context, 0.012)),
                          SizedBox(
                            height: ResponsiveHelper.height(context, 0.037),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _appliances.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final appliance = _appliances[index];
                                return _ApplianceCard(info: appliance);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
        floatingActionButton: Bounceable(
          onTap: () {},
          child: FloatingActionButton(
            onPressed: _showMealImagePicker,
            backgroundColor: const Color(0xFF5BB5C8),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    } catch (e, stackTrace) {
      debugPrint('에러: 홈 화면 빌드 중 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      // 에러 발생 시 에러 화면 표시
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                '화면을 불러오는 중 오류가 발생했습니다',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '에러: $e',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadInitialData();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
      );
    }
  }
}

// 칼로리 아크 게이지
class CalorieArcGauge extends StatelessWidget {
  const CalorieArcGauge({
    super.key,
    required this.current,
    required this.target,
    required this.gradientColors,
    required this.child,
  });

  final double current;
  final double target;
  final List<Color> gradientColors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _CalorieArcPainter(
                  progress: (current / target).clamp(0.0, 1.0),
                  gradientColors: gradientColors,
                ),
              ),
              // 아기 이미지를 위로 이동하여 아크 게이지와 가까워지도록 조정
              Transform.translate(
                offset: Offset(0, -height * 0.15), // 높이의 15%만큼 위로 이동
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalorieArcPainter extends CustomPainter {
  _CalorieArcPainter({
    required this.progress,
    required this.gradientColors,
  });

  final double progress;
  final List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFF7F7F7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;

    final arcRect = Rect.fromCircle(center: center, radius: radius - 6);
    canvas.drawArc(
      arcRect,
      math.pi,
      math.pi,
      false,
      backgroundPaint,
    );

    final gradient = SweepGradient(
      startAngle: math.pi,
      endAngle: math.pi * 2,
      colors: gradientColors,
    );
    final arcPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;

    canvas.drawArc(
      arcRect,
      math.pi,
      math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CalorieArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.gradientColors != gradientColors;
  }
}

// 가전 제품 카드
class _ApplianceCard extends StatelessWidget {
  const _ApplianceCard({required this.info});

  final _ApplianceInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ResponsiveHelper.width(context, 0.253),
      height: ResponsiveHelper.height(context, 0.037),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.width(context, 0.021),
        vertical: ResponsiveHelper.height(context, 0.005),
      ),
      decoration: BoxDecoration(
        color: const Color(0x45CDCDCD),
        borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.021)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ResponsiveHelper.width(context, 0.064),
            height: ResponsiveHelper.height(context, 0.023),
            child: Image.asset(
              info.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: ResponsiveHelper.width(context, 0.064),
                  height: ResponsiveHelper.height(context, 0.023),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.width(context, 0.011)),
                  ),
                  child: Icon(
                    info.name.contains('오븐') ? Icons.microwave : Icons.kitchen,
                    size: ResponsiveHelper.fontSize(context, 14),
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          SizedBox(width: ResponsiveHelper.width(context, 0.016)),
          Expanded(
            child: Text(
              info.name,
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, 10),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 데이터 모델
class _ApplianceInfo {
  const _ApplianceInfo({
    required this.name,
    required this.assetPath,
  });

  final String name;
  final String assetPath;
}

class _SupplementOption {
  const _SupplementOption({
    required this.id,
    required this.label,
    required this.nutrient,
  });

  final String id;
  final String label;
  final NutrientType nutrient;
}

class _RecommendedMeal {
  const _RecommendedMeal({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.calories,
    required this.tags,
    required this.backgroundColor,
  });

  final String id;
  final String name;
  final String imagePath;
  final int calories;
  final List<String> tags;
  final Color backgroundColor;
}

// NutrientType enum은 lib/model/nutrient_type.dart로 이동됨

/// 칼로리 게이지와 영양소 그리드를 함께 표시하는 섹션
class _CalorieAndNutrientSection extends StatelessWidget {
  const _CalorieAndNutrientSection({
    required this.currentCalorie,
    required this.targetCalorie,
    required this.nutrientData,
    required this.textTheme,
  });

  final double currentCalorie;
  final double targetCalorie;
  final List<Map<String, dynamic>> nutrientData;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final gaugeHeight = ResponsiveHelper.height(context, 0.14);
    final spacing = ResponsiveHelper.width(context, 0.003);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // 가운데 정렬로 변경
      mainAxisAlignment: MainAxisAlignment.start, // 가운데 정렬
      children: [
        // 칼로리 게이지 영역
        Expanded(
          flex: 2,
          child: _CalorieGaugeWidget(
            currentCalorie: currentCalorie,
            targetCalorie: targetCalorie,
            height: gaugeHeight,
            textTheme: textTheme,
          ),
        ),
        SizedBox(width: spacing),
        // 영양소 그리드 영역
        Expanded(
          flex: 3,
          child: SizedBox(
            height: gaugeHeight,
            child: NutrientGrid(nutrients: nutrientData),
          ),
        ),
      ],
    );
  }
}

/// 칼로리 게이지 위젯
class _CalorieGaugeWidget extends StatelessWidget {
  const _CalorieGaugeWidget({
    required this.currentCalorie,
    required this.targetCalorie,
    required this.height,
    required this.textTheme,
  });

  final double currentCalorie;
  final double targetCalorie;
  final double height;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // 최소 크기만 차지
      mainAxisAlignment: MainAxisAlignment.center, // 가운데 정렬
      crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
      children: [
        SizedBox(
          width: double.infinity,
          height: height,
          child: CalorieArcGauge(
            current: currentCalorie,
            target: targetCalorie,
            gradientColors: const [
              Color(0xFFBCE7F0),
              Color(0xFFFEF493),
              Color(0xFFDDEDC1),
              Color(0xFFBCE7F0),
            ],
            child: _BabyImageWidget(currentCalorie: currentCalorie),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -ResponsiveHelper.height(context, 0.012)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center, // 가운데 정렬
            child: Text(
              '${currentCalorie.toStringAsFixed(0)}Kcal',
              textAlign: TextAlign.center, // 텍스트 가운데 정렬
              style:
                  textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: ResponsiveHelper.fontSize(context, 22),
                    height: 1.0,
                    letterSpacing: 0.5,
                  ) ??
                  TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, 22),
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 아기 이미지 위젯
class _BabyImageWidget extends StatelessWidget {
  const _BabyImageWidget({
    required this.currentCalorie,
  });

  final double currentCalorie;

  String _getBabyImagePath() {
    if (currentCalorie >= 2000) {
      return 'assets/image/happy_baby.png';
    } else if (currentCalorie <= 600) {
      return 'assets/image/cry_baby.png';
    } else {
      return 'assets/image/baby.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = ResponsiveHelper.width(context, 0.24);

    return Center(
      child: Image.asset(
        _getBabyImagePath(),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: const Color(0xFFBCE7F0).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.child_care,
              size: ResponsiveHelper.fontSize(context, 50),
              color: const Color(0xFF5BB5C8),
            ),
          );
        },
      ),
    );
  }
}
