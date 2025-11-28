import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widget/bottom_bar_widget.dart';
import 'chat_pages.dart';
import 'report_pages.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _qaController = TextEditingController();

  final String _userName = '김레제';
  final String _pregnancyWeekLabel = '임신 N 주차';

  final double _currentCalorie = 1000;
  final double _targetCalorie = 2000;

  // TODO(eunbee): 실제 영양제 1회 섭취 시 증가할 함량으로 치환해 주세요.
  static const double supplementValue = 30.0;

  final Map<_NutrientType, double> _baseNutrientProgress = {
    _NutrientType.iron: 70,
    _NutrientType.folate: 0,
    _NutrientType.calcium: 0,
    _NutrientType.vitaminD: 0,
    _NutrientType.omega3: 0,
  };

  late final Map<_NutrientType, double> _nutrientProgress;

  final List<_NutrientDefinition> _nutrientDefinitions = const [
    _NutrientDefinition(
      type: _NutrientType.iron,
      label: '철분',
      activeColor: Color(0xFFFef493),
    ),
    _NutrientDefinition(
      type: _NutrientType.folate,
      label: '엽산',
      activeColor: Color(0xFFE6E0E9),
    ),
    _NutrientDefinition(
      type: _NutrientType.calcium,
      label: '칼슘',
      activeColor: Color(0xFFE6E0E9),
    ),
    _NutrientDefinition(
      type: _NutrientType.vitaminD,
      label: '비타민D',
      activeColor: Color(0xFFE6E0E9),
    ),
    _NutrientDefinition(
      type: _NutrientType.omega3,
      label: '오메가-3',
      activeColor: Color(0xFFE6E0E9),
    ),
  ];

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
      label: '영양제',
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

  final Set<String> _selectedSupplements = {};

  @override
  void initState() {
    super.initState();
    _nutrientProgress = Map<_NutrientType, double>.from(_baseNutrientProgress);
  }

  @override
  void dispose() {
    _qaController.dispose();
    super.dispose();
  }

  void _handleAskSubmit() {
    final query = _qaController.text.trim();
    if (query.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          initialText: query,
        ),
      ),
    );
  }

  void _toggleSupplement(String supplementId) {
    final option = _supplements.firstWhere((element) => element.id == supplementId);

    setState(() {
      if (_selectedSupplements.contains(supplementId)) {
        _selectedSupplements.remove(supplementId);
        _nutrientProgress[option.nutrient] = (_nutrientProgress[option.nutrient]! - supplementValue).clamp(0, 100);
      } else {
        _selectedSupplements.add(supplementId);
        _nutrientProgress[option.nutrient] = (_nutrientProgress[option.nutrient]! + supplementValue).clamp(0, 100);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                clipBehavior: Clip.hardEdge,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 20, bottom: 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFBCE7F0),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(5),
                  ),
                ),
                child: SizedBox(
                  height: 440,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        bottom: 0, // 바닥에 딱 붙이기
                        left: 0, // 양옆 여백 (취향껏 조절 가능, 0으로 하면 꽉 참)
                        right: 0,
                        child: Container(
                          height: 280, // 반원 높이 (아기 이미지 뒤에 깔릴 정도)
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(260), // 둥글기 (높이보다 큰 값을 줘야 완만한 아치가 됨)
                            ),
                          ),
                        ),
                      ),
                      // Positioned.fill 부분을 이걸로 통째로 바꾸세요
                      Positioned.fill(
                        child: Padding(
                          // ✅ 1. 여백 추가 (글자가 벽에 붙지 않게)
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            // ✅ 2. 전체를 '왼쪽 정렬'로 변경 (글자, 버튼을 위해)
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 40), // 상단 여백 (조절 가능)
                              // 이름
                              Text(
                                '$_userName 홈',
                                style:
                                    textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              const SizedBox(height: 6),

                              // 임신 주차
                              Text(
                                _pregnancyWeekLabel,
                                style:
                                    textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                              ),

                              const SizedBox(height: 12), // 글자와 버튼 사이 간격
                              // ✅ 3. Row를 없애고 버튼을 여기로 가져옴 (세로 배치)
                              SizedBox(
                                height: 28,
                                child: TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/healthinfo'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 0,
                                    ),
                                    backgroundColor: const Color(0xFF5BB5C8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    '건강정보 업데이트',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // 아기 위쪽 여백 (화면 보면서 조절하세요)
                              const SizedBox(height: 40),

                              // ✅ 4. 아기랑 게이지는 '가운데 정렬'로 따로 설정 (Align 사용)
                              Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 195, // 300은 너무 큽니다. 195 추천
                                  height: 195,
                                  child: CalorieArcGauge(
                                    current: _currentCalorie,
                                    target: _targetCalorie,
                                    gradientColors: const [
                                      Color(0xFFFEF493),
                                      Color(0xFFDDEDC1),
                                      Color(0xFFBCE7F0),
                                    ],
                                    child: SizedBox(
                                      height: 175,
                                      width: 175,
                                      child: Image.asset(
                                        'assets/image/baby.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 4),

                              // ✅ 5. 칼로리 텍스트도 '가운데 정렬'
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  '${_currentCalorie.toStringAsFixed(0)} Kcal',
                                  style:
                                      textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.0,
                                      ) ??
                                      const TextStyle(
                                        fontSize: 40, // 30보다 40 추천
                                        fontWeight: FontWeight.w700,
                                        height: 1.0,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: '오늘 총 영양 요약',
                      actionLabel: '종합리포트 가기',
                      onActionTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0ECE4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _nutrientDefinitions
                            .map(
                              (definition) => SizedBox(
                                width: 68,
                                height: 77,
                                child: _NutrientProgressBar(
                                  definition: definition,
                                  percent: _nutrientProgress[definition.type] ?? 0,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _SectionHeader(
                      title: '오늘 영양제',
                      actionLabel: '영양제 추가하기',
                      onActionTap: () {},
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0ECE4)),
                      ),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: _supplements
                            .map(
                              (option) => SizedBox(
                                width: 110,
                                child: _SupplementCheckbox(
                                  option: option,
                                  selected: _selectedSupplements.contains(option.id),
                                  onChanged: () => _toggleSupplement(option.id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '먹어도 되나요?',
                      style:
                          textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ) ??
                          const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(55),
                        border: Border.all(color: const Color(0xFFF0ECE4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 18, color: Color(0xFF0F0F0F)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _qaController,
                              decoration: const InputDecoration(
                                hintText: '궁금한 음식/약을 물어보세요',
                                hintStyle: TextStyle(
                                  color: Color(0xFFBDBDBD),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _handleAskSubmit(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _handleAskSubmit,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFBCE7F0),
                              ),
                              child: const Icon(
                                Icons.send,
                                size: 16,
                                color: Color(0xFF0F0F0F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '즐겨 찾는 제품',
                      style:
                          textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ) ??
                          const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _appliances.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final appliance = _appliances[index];
                          return _ApplianceCard(info: appliance);
                        },
                      ),
                    ),
                  ],
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
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(240, 240),
            painter: _CalorieArcPainter(
              progress: (current / target).clamp(0.0, 1.0),
              gradientColors: gradientColors,
            ),
          ),
          child,
        ],
      ),
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
      ..strokeWidth = 30;

    final arcRect = Rect.fromCircle(center: center, radius: radius - 10);
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
      ..strokeWidth = 30;

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            backgroundColor: const Color(0xFFBCE7F0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F0F0F),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _NutrientProgressBar extends StatelessWidget {
  const _NutrientProgressBar({
    required this.definition,
    required this.percent,
  });

  final _NutrientDefinition definition;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final clampedPercent = percent.clamp(0, 100);
    final fillHeight = 53 * (clampedPercent / 100);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: fillHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: clampedPercent > 0 ? definition.activeColor : const Color(0xFFE7E1EA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${clampedPercent.round()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: clampedPercent > 0 ? const Color(0xFF0F0F0F) : const Color(0xFFBABABA),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                definition.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupplementCheckbox extends StatelessWidget {
  const _SupplementCheckbox({
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  final _SupplementOption option;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: (_) => onChanged(),
            activeColor: const Color(0xFF5BB5C8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Color(0x26000000)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(
            option.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  const _ApplianceCard({required this.info});

  final _ApplianceInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 113,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x45CDCDCD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 29,
            height: 23,
            child: Image.asset(info.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.name,
              style: const TextStyle(
                fontSize: 11,
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

class _ApplianceInfo {
  const _ApplianceInfo({
    required this.name,
    required this.assetPath,
  });

  final String name;
  final String assetPath;
}

class _NutrientDefinition {
  const _NutrientDefinition({
    required this.type,
    required this.label,
    required this.activeColor,
  });

  final _NutrientType type;
  final String label;
  final Color activeColor;
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

enum _NutrientType { iron, folate, calcium, vitaminD, omega3 }
