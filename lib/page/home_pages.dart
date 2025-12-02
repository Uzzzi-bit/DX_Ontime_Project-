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
  // 영양소 섭취량 (0.0 ~ 100.0 퍼센트) - 리포트 페이지와 영양제 체크 시 증가
  // [테스트용] 80%, 90% 확인을 위해 일부 수치 조절
  Map<_NutrientType, double> _nutrientProgress = {
    _NutrientType.iron: 70.0, // 철분 기본값
    _NutrientType.vitaminD: 80.0, // 비타민D - 테스트용 80%
    _NutrientType.folate: 90.0, // 엽산 - 테스트용 90%
    _NutrientType.omega3: 0.0, // 오메가-3 기본값
    _NutrientType.calcium: 0.0, // 칼슘 기본값
    _NutrientType.choline: 0.0, // 콜린 기본값
  };

  // 영양제 체크리스트 (6개)
  final List<_SupplementOption> _supplements = const [
    _SupplementOption(
      id: 'iron-pill',
      label: '철분제',
      nutrient: _NutrientType.iron,
    ),
    _SupplementOption(
      id: 'calcium',
      label: '칼슘',
      nutrient: _NutrientType.calcium,
    ),
    _SupplementOption(
      id: 'vitamin-complex',
      label: '종합영양제',
      nutrient: _NutrientType.folate,
    ),
    _SupplementOption(
      id: 'omega3',
      label: 'DHA(오메가-3)',
      nutrient: _NutrientType.omega3,
    ),
    _SupplementOption(
      id: 'vitaminD',
      label: '비타민D',
      nutrient: _NutrientType.vitaminD,
    ),
    _SupplementOption(
      id: 'choline',
      label: '콜린',
      nutrient: _NutrientType.choline,
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

  Set<String> _selectedSupplements = {}; // 임시 데이터

  List<String> get _supplementLabels => _supplements.map((s) => s.label).toList();

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
      {'label': '철분', 'progress': _nutrientProgress[_NutrientType.iron] ?? 0.0},
      {'label': '비타민D', 'progress': _nutrientProgress[_NutrientType.vitaminD] ?? 0.0},
      {'label': '엽산', 'progress': _nutrientProgress[_NutrientType.folate] ?? 0.0},
      {'label': '오메가-3', 'progress': _nutrientProgress[_NutrientType.omega3] ?? 0.0},
      {'label': '칼슘', 'progress': _nutrientProgress[_NutrientType.calcium] ?? 0.0},
      {'label': '콜린', 'progress': _nutrientProgress[_NutrientType.choline] ?? 0.0},
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

  void _toggleSupplement(String supplementLabel) {
    final supplementId = _supplements.firstWhere((s) => s.label == supplementLabel).id;
    final option = _supplements.firstWhere((element) => element.id == supplementId);
    // TODO: [API] 영양제 1알당 함량 정보 GET
    const double supplementValuePerPill = 30.0; // 영양제 1알당 증가량 (예시)

    setState(() {
      if (_selectedSupplements.contains(supplementId)) {
        _selectedSupplements.remove(supplementId);
        _nutrientProgress[option.nutrient] = (_nutrientProgress[option.nutrient]! - supplementValuePerPill).clamp(
          0.0,
          100.0,
        );
      } else {
        _selectedSupplements.add(supplementId);
        _nutrientProgress[option.nutrient] = (_nutrientProgress[option.nutrient]! + supplementValuePerPill).clamp(
          0.0,
          100.0,
        );
      }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 이미지 표시
            Image.asset(
              'assets/image/img_app_home.png',
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image,
                  size: 200,
                  color: Color(0xFFD0D0D0),
                );
              },
            ),
          ],
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
                          supplements: _supplementLabels,
                          selectedSupplements: _selectedSupplements
                              .map((id) => _supplements.firstWhere((s) => s.id == id).label)
                              .toSet(),
                          onToggle: _toggleSupplement,
                          onAdd: () {
                            // TODO: [API] 영양제 추가하기 기능
                          },
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
  final _NutrientType nutrient;
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

enum _NutrientType {
  iron,
  vitaminD,
  folate,
  omega3,
  calcium,
  choline,
}
