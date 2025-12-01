import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _qaController = TextEditingController();
  String? _selectedImagePath; // 선택된 이미지 경로 저장

  // TODO: [SERVER] 사용자 이름 및 임신 주차 정보 GET
  final String _userName = '김레제';

  // TODO: [SERVER] 출산 예정일 및 임신 시작일 정보 GET
  // 출산 예정일: 2026.07.01
  final DateTime _dueDate = DateTime(2026, 7, 1);
  // 임시: 현재 임신 주차를 20주차로 고정
  static const int _fixedPregnancyWeek = 20;

  // TODO: [DB] 금일 칼로리 섭취량 및 목표량 GET
  double _currentCalorie = 1000.0; // 임시 데이터
  double _targetCalorie = 2000.0; // 임시 데이터

  // TODO: [DB] 금일 영양소 섭취 현황 데이터 로드
  // 영양소 섭취량 (0.0 ~ 100.0 퍼센트) - 리포트 페이지와 영양제 체크 시 증가
  Map<_NutrientType, double> _nutrientProgress = {
    _NutrientType.iron: 70.0, // 예시: 70% 섭취
    _NutrientType.vitaminD: 0.0,
    _NutrientType.folate: 0.0,
    _NutrientType.omega3: 0.0,
    _NutrientType.calcium: 0.0,
    _NutrientType.choline: 0.0,
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
  // 오늘의 추천 식단 (Mock Data) - 3개 아이템
  final List<_RecommendedMeal> _recommendedMeals = const [
    _RecommendedMeal(
      id: 'salmon-steak',
      name: '연어스테이크',
      imagePath: 'assets/image/sample_food.png',
      calories: 350,
      tags: ['오메가-3', '비타민 D'],
      backgroundColor: Color(0xFFD2ECBF),
    ),
    _RecommendedMeal(
      id: 'cold-noodles',
      name: '냉모밀',
      imagePath: 'assets/image/sample_food.png',
      calories: 400,
      tags: ['단백질', '미네랄'],
      backgroundColor: Color(0xFFFEF493),
    ),
    _RecommendedMeal(
      id: 'seaweed-soup',
      name: '미역국',
      imagePath: 'assets/image/sample_food.png',
      calories: 150,
      tags: ['철분', '칼슘'],
      backgroundColor: Color(0xFFBCE7F0),
    ),
  ];

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
    // 데이터가 없을 경우 임시 데이터 반환
    if (_recommendedMeals.isEmpty) {
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
    return _recommendedMeals.map((meal) {
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

  // 임신 주차 계산 (임시: 20주차로 고정)
  int _getPregnancyWeek() {
    // TODO: [SERVER] 실제 임신 주차 정보로 대체
    return _fixedPregnancyWeek;
  }

  // 임신 진행률 계산 (0.0 ~ 1.0) - 출산예정일까지의 남은 기간 기준
  // 20주차 = 140일 경과, 전체 280일 중 50% 진행
  double _getPregnancyProgress() {
    // TODO: [SERVER] 실제 임신 진행률로 대체
    // 임시: 20주차 = 140일 경과 / 280일 = 0.5 (50%)
    const int currentWeek = _fixedPregnancyWeek;
    const int totalWeeks = 40;
    const double progress = currentWeek / totalWeeks;
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
    const double supplementValuePerPill = 10.0; // 영양제 1알당 증가량 (예시)

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecipeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          onRefresh: () {
                            // TODO: [SERVER] 추천 식단 새로고침
                          },
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
