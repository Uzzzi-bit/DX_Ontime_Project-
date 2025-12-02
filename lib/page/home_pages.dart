import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../repository/user_repository.dart';
import '../model/supplement_effects.dart';
import '../model/nutrient_type.dart';

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

      // UserRepository에서 사용자 데이터 불러오기
      final userData = await UserRepository.getDummyUser();

      if (mounted) {
        setState(() {
          _isMomCareMode = isMomCareMode;
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 에러 발생 시 기본값 사용
      if (mounted) {
        setState(() {
          _isMomCareMode = false;
          _isLoading = false;
        });
      }
    }
  }

  final ImagePicker _picker = ImagePicker();

  // TODO: [SERVER] 추천 식단 업데이트 메서드
  //
  // [서버 연동 시 구현 사항]
  // report_pages.dart에서 AI 추천 식단이 변경되었을 때 호출되는 메서드
  // void _updateRecommendedMeals() async {
  //   try {
  //     // 서버에서 최신 추천 식단 정보 GET
  //     // final updatedRecipes = await api.getRecommendedRecipes();
  //     // setState(() {
  //     //   // _recommendedMeals를 업데이트된 데이터로 갱신
  //     // });
  //   } catch (e) {
  //     // 에러 처리
  //   }
  // }

  // 사용자 정보 (UserRepository에서 로드)
  String get _userName => _userData?.nickname ?? '김레제';
  DateTime get _dueDate => _userData?.dueDate ?? DateTime(2026, 7, 1);
  int get _pregnancyWeek => _userData?.pregnancyWeek ?? 20;

  // TODO: [DB] 금일 칼로리 섭취량 및 목표량 GET
  double _currentCalorie = 1000.0; // 임시 데이터
  double _targetCalorie = 2000.0; // 임시 데이터

  // TODO: [DB] 금일 영양소 섭취 현황 데이터 로드
  // 기본 영양소 섭취량 (0.0 ~ 100.0 퍼센트) - 리포트 페이지/음식 섭취 등으로 채워진 기본값 (영양제 제외)
  // [테스트용] 80%, 90% 확인을 위해 일부 수치 조절
  final Map<NutrientType, double> _baseNutrientProgress = {
    NutrientType.iron: 70.0, // 철분 기본값
    NutrientType.vitaminD: 80.0, // 비타민D - 테스트용 80%
    NutrientType.folate: 90.0, // 엽산 - 테스트용 90%
    NutrientType.omega3: 0.0, // 오메가-3 기본값
    NutrientType.calcium: 0.0, // 칼슘 기본값
    NutrientType.choline: 0.0, // 콜린 기본값
  };

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
      id: 'choline',
      label: '콜린',
      nutrient: NutrientType.choline,
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
    final recipes = RecipeScreen.getRecommendedRecipes();
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
    // 데이터가 없을 경우 임시 데이터 반환
    if (_nutrientProgress.isEmpty) {
      return [
        {'label': '철분', 'progress': 0.0},
        {'label': '비타민D', 'progress': 0.0},
        {'label': '엽산', 'progress': 0.0},
        {'label': '오메가-3', 'progress': 0.0},
        {'label': '칼슘', 'progress': 0.0},
        {'label': '콜린', 'progress': 0.0},
      ];
    }
    return [
      {'label': '철분', 'progress': _nutrientProgress[NutrientType.iron] ?? 0.0},
      {'label': '비타민D', 'progress': _nutrientProgress[NutrientType.vitaminD] ?? 0.0},
      {'label': '엽산', 'progress': _nutrientProgress[NutrientType.folate] ?? 0.0},
      {'label': '오메가-3', 'progress': _nutrientProgress[NutrientType.omega3] ?? 0.0},
      {'label': '칼슘', 'progress': _nutrientProgress[NutrientType.calcium] ?? 0.0},
      {'label': '콜린', 'progress': _nutrientProgress[NutrientType.choline] ?? 0.0},
    ];
  }

  List<Map<String, dynamic>> get _mealData {
    final meals = _recommendedMeals;
    // 데이터가 없을 경우 임시 데이터 반환
    if (meals.isEmpty) {
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
    setState(() {
      _selectedImagePath = file.path;
    });
    // TODO: [API] 이미지 업로드 및 분석 요청
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }

  /// 플로팅 버튼 클릭 시 이미지 선택 옵션 표시
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
                    '식단 사진 추가',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFF5BB5C8)),
                  title: const Text('사진 직접 촬영'),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await _handleMealImageCapture(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFF5BB5C8)),
                  title: const Text('앨범에서 추가'),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await _handleMealImageCapture(ImageSource.gallery);
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

  /// 식단 사진 캡처/선택 처리 (임시 기능)
  Future<void> _handleMealImageCapture(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null && mounted) {
        // TODO: [API] 식단 사진 업로드 및 분석 기능 구현
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera ? '사진이 촬영되었습니다. (임시 기능)' : '앨범에서 사진이 선택되었습니다. (임시 기능)',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF5BB5C8),
          ),
        );
        // 여기에 실제 식단 분석 및 저장 로직 추가 예정
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera ? '카메라 오류: ${e.toString()}' : '앨범 오류: ${e.toString()}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(10),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage('assets/image/blueprint.png'),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
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
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 110 / 80,
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
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: iconPath != null && iconPath.isNotEmpty
                                ? Image.asset(
                                    iconPath,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox.shrink();
                                    },
                                  )
                                : const SizedBox(height: 60),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
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
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
        bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
      );
    }

    // Mom Care Mode가 OFF일 때
    if (!_isMomCareMode) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildModeOffView(),
        bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
      );
    }

    // Mom Care Mode가 ON일 때 - 기존 대시보드
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final now = DateTime.now();
    final dateFormat = DateFormat('M월 d일 (E)', 'ko');

    final pregnancyWeek = _getPregnancyWeek();
    final pregnancyProgress = _getPregnancyProgress();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
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
                offset: const Offset(0, -170), // 흰색 박스 배경 침투 조절
                child: RoundedContainer(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dateFormat.format(now),
                                style:
                                    textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ReportScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  backgroundColor: const Color(0xFFBCE7F0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  foregroundColor: const Color(0xFF49454F),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '종합리포트 가기',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      height: 130,
                                      child: CalorieArcGauge(
                                        current: _currentCalorie,
                                        target: _targetCalorie,
                                        gradientColors: const [
                                          Color(0xFFBCE7F0),
                                          Color(0xFFFEF493),
                                          Color(0xFFDDEDC1),
                                          Color(0xFFBCE7F0),
                                        ],
                                        child: SizedBox(
                                          height: 110,
                                          width: 110,
                                          child: Image.asset(
                                            'assets/image/baby.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 90,
                                                height: 90,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFBCE7F0).withOpacity(0.3),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.child_care,
                                                  size: 50,
                                                  color: Color(0xFF5BB5C8),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(0, -10),
                                      child: Text(
                                        '${_currentCalorie.toStringAsFixed(0)}Kcal',
                                        style:
                                            textTheme.displaySmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 24,
                                              height: 1.0,
                                              letterSpacing: 0.5,
                                            ) ??
                                            const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: NutrientGrid(nutrients: _nutrientData),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SupplementChecklist(
                          supplements: _supplementIds
                              .map((id) => _supplements.firstWhere((s) => s.id == id).label)
                              .toList(),
                          selectedSupplements: _selectedSupplementIds
                              .map((id) => _supplements.firstWhere((s) => s.id == id).label)
                              .toSet(),
                          onToggle: (label) {
                            final id = _supplements.firstWhere((s) => s.label == label).id;
                            _toggleSupplement(id);
                          },
                          onAdd: () {
                            // TODO: [API] 영양제 추가하기 기능
                          },
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '※ 영양제 효과는 1일 권장량 대비 평균적인 퍼센트로 가정한 값입니다. 실제 제품과는 차이가 있을 수 있어요.',
                            style:
                                textTheme.bodySmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.09,
                                  height: 1.3,
                                ) ??
                                TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.09,
                                  height: 1.3,
                                ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        EatCheckSection(
                          controller: _qaController,
                          onSubmit: _handleAskSubmit,
                          onImageSelected: _handleImageSelected,
                          selectedImagePath: _selectedImagePath,
                          onRemoveImage: _removeSelectedImage,
                        ),
                        const SizedBox(height: 32),
                        TodayMealSection(
                          meals: _mealData,
                          onMealTap: _navigateToRecipe,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '즐겨 찾는 제품',
                          style:
                              textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ) ??
                              const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 30,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showMealImagePicker,
        backgroundColor: const Color(0xFF5BB5C8),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
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
              child,
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
      width: 95,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x45CDCDCD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 19,
            child: Image.asset(
              info.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 24,
                  height: 19,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    info.name.contains('오븐') ? Icons.microwave : Icons.kitchen,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              info.name,
              style: const TextStyle(
                fontSize: 10,
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
