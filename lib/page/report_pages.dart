import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widget/bottom_bar_widget.dart';
import '../theme/color_palette.dart';
import 'recipe_pages.dart';
import 'analysis_pages.dart';

class MealRecord {
  final String mealType;
  final String? imagePath;
  final String? menuText;
  final bool hasRecord;

  MealRecord({
    required this.mealType,
    this.imagePath,
    this.menuText,
    required this.hasRecord,
  });
}

class NutrientSlot {
  final String name;
  final double current; // 현재 섭취량 (mg)
  final double target; // 목표 섭취량 (mg)
  final double percent; // 퍼센트

  NutrientSlot({
    required this.name,
    required this.current,
    required this.target,
    required this.percent,
  });
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Mock Data - State 변수로 관리
  final String _userName = '김레제';
  late DateTime _selectedDate;
  late DateTime _selectedWeekDate; // 주간 달력에서 선택된 날짜
  late int _selectedMonth; // 현재 월로 초기화
  final PageController _weekPageController = PageController(initialPage: 1000); // 무한 스크롤을 위한 큰 초기값

  @override
  void initState() {
    super.initState();
    // 명시적으로 초기화
    final now = DateTime.now();
    _selectedDate = now;
    _selectedWeekDate = now;
    _selectedMonth = now.month;
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  final String _lackingNutrient = '단백질, 비타민';
  final String _recommendedFood = '닭가슴살 샐러드';

  // 영양소 데이터 유무
  final bool _hasNutrientData = true; // 데이터 시각화 활성화

  // 영양소 슬롯 데이터 (하늘색 계열로 통일)
  final List<NutrientSlot> _nutrientSlots = [
    NutrientSlot(
      name: '탄수화물',
      current: 180.0,
      target: 300.0,
      percent: 60.0,
    ),
    NutrientSlot(
      name: '나트륨',
      current: 2400.0,
      target: 3000.0,
      percent: 80.0,
    ),
    NutrientSlot(
      name: '단백질',
      current: 40.0,
      target: 100.0,
      percent: 40.0,
    ),
    NutrientSlot(
      name: '지방',
      current: 20.0,
      target: 100.0,
      percent: 20.0,
    ),
    NutrientSlot(
      name: '칼슘',
      current: 600.0,
      target: 1000.0,
      percent: 60.0,
    ),
    NutrientSlot(
      name: '철분',
      current: 15.0,
      target: 30.0,
      percent: 50.0,
    ),
  ];

  // 식사 기록 데이터
  final List<MealRecord> _mealRecords = [
    MealRecord(
      mealType: '아침',
      imagePath: 'assets/image/sample_food.png',
      menuText: '김치찌개, 현미밥, 녹두전, 콩자반, 멸치볶음, 진미채',
      hasRecord: true,
    ),
    MealRecord(
      mealType: '점심',
      hasRecord: false,
    ),
    MealRecord(
      mealType: '간식',
      hasRecord: false,
    ),
    MealRecord(
      mealType: '저녁',
      hasRecord: false,
    ),
  ];

  List<DateTime> _getWeekDates(DateTime date) {
    final week = <DateTime>[];
    // 안전하게 weekday 접근
    try {
      // 일요일을 주의 시작으로 설정 (weekday: 7 -> 0으로 변환)
      final weekday = date.weekday == 7 ? 0 : date.weekday;
      final startOfWeek = date.subtract(Duration(days: weekday));
      for (int i = 0; i < 7; i++) {
        week.add(startOfWeek.add(Duration(days: i)));
      }
    } catch (e) {
      // 에러 발생 시 현재 날짜로 대체
      final now = DateTime.now();
      final weekday = now.weekday == 7 ? 0 : now.weekday;
      final startOfWeek = now.subtract(Duration(days: weekday));
      for (int i = 0; i < 7; i++) {
        week.add(startOfWeek.add(Duration(days: i)));
      }
    }
    return week;
  }

  void _onMonthChanged(int? month) {
    if (month != null) {
      setState(() {
        _selectedMonth = month;
        // 선택된 월의 첫 번째 날로 변경 (안전하게 처리)
        try {
          _selectedWeekDate = DateTime(_selectedWeekDate.year, month, 1);
        } catch (e) {
          // 에러 발생 시 현재 날짜로 대체
          final now = DateTime.now();
          _selectedWeekDate = DateTime(now.year, month, 1);
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedMonth = picked.month;
      });
    }
  }

  void _navigateToRecipe() {
    // TODO: [SERVER] AI 추천 식단 변경 시 홈 화면 업데이트
    //
    // [서버 연동 시 구현 사항]
    // 1. 사용자가 AI 추천 식단 배너를 클릭하여 레시피 페이지로 이동
    // 2. 레시피 페이지에서 새로운 추천 식단을 선택하거나 변경할 경우:
    //    - 서버에 새로운 추천 식단 정보 POST/PUT 요청
    //    - 서버 응답으로 업데이트된 추천 식단 리스트 받아옴
    // 3. 홈 화면(home_pages.dart)의 추천 식단을 업데이트하는 방법:
    //    - 방법 1: Navigator.pop() 시 콜백 함수로 홈 화면의 setState() 호출
    //    - 방법 2: 전역 상태 관리(Provider, Riverpod 등)로 추천 식단 상태 공유
    //    - 방법 3: 서버에서 푸시 알림으로 홈 화면에 업데이트 신호 전송
    //    - 방법 4: 홈 화면 진입 시 항상 서버에서 최신 추천 식단 정보 GET
    //
    // 예시 코드 (방법 1 - 콜백 사용):
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => RecipeScreen(
    //       onRecipeUpdated: (updatedRecipes) {
    //         // 서버에 업데이트된 추천 식단 POST/PUT
    //         // await api.updateRecommendedRecipes(updatedRecipes);
    //         // 홈 화면 업데이트를 위한 콜백 또는 상태 관리
    //       },
    //     ),
    //   ),
    // ).then((_) {
    //   // 레시피 페이지에서 돌아올 때 홈 화면 새로고침
    //   // setState(() {}); // 또는 전역 상태 업데이트
    // });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecipeScreen()),
    );
  }

  void _navigateToMealRecord(String mealType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnalysisScreen(),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _selectedWeekDate = now;
      _selectedMonth = now.month;
    });
    // PageView를 오늘 주로 이동
    _weekPageController.jumpToPage(1000);
  }

  DateTime _getWeekStartDate(int pageOffset) {
    final now = DateTime.now();
    final weekday = now.weekday == 7 ? 0 : now.weekday;
    final startOfCurrentWeek = now.subtract(Duration(days: weekday));
    return startOfCurrentWeek.add(Duration(days: (pageOffset - 1000) * 7));
  }

  @override
  Widget build(BuildContext context) {
    final todayFormat = DateFormat('M.d E', 'ko');
    final todayText = todayFormat.format(DateTime.now());

    return Scaffold(
      backgroundColor: ColorPalette.bg100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: ColorPalette.text100,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '오늘',
              style: TextStyle(
                color: ColorPalette.text100,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              todayText,
              style: TextStyle(
                color: ColorPalette.text100,
                fontSize: 22,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 선택 섹션 (월 드롭다운, Today 버튼, 달력 버튼을 같은 줄에)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: ColorPalette.bg300),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.expand_more,
                      size: 16,
                      color: ColorPalette.text200,
                    ),
                    items: List.generate(12, (index) => index + 1)
                        .map(
                          (month) => DropdownMenuItem<int>(
                            value: month,
                            child: Text(
                              '$month월',
                              style: const TextStyle(
                                color: ColorPalette.text200,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onMonthChanged,
                  ),
                ),
                // Today 버튼과 달력 버튼
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 오늘이 아닌 날짜 선택 시 'Today' 버튼 표시
                    if (!_isToday(_selectedWeekDate))
                      TextButton(
                        onPressed: _goToToday,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: ColorPalette.primary100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            color: ColorPalette.text100,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (!_isToday(_selectedWeekDate)) const SizedBox(width: 8),
                    // 달력 버튼
                    IconButton(
                      onPressed: _selectDate,
                      icon: const Icon(
                        Icons.calendar_today,
                        color: ColorPalette.text200,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 주간 달력 (PageView로 전 주/다음 주 스크롤 가능)
            SizedBox(
              height: 70,
              child: PageView.builder(
                controller: _weekPageController,
                onPageChanged: (page) {
                  final weekStart = _getWeekStartDate(page);
                  setState(() {
                    _selectedWeekDate = weekStart;
                    _selectedMonth = weekStart.month;
                  });
                },
                itemBuilder: (context, page) {
                  final weekStart = _getWeekStartDate(page);
                  final weekDates = _getWeekDates(weekStart);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: weekDates.map((date) {
                      final isSelected =
                          date.day == _selectedWeekDate.day &&
                          date.month == _selectedWeekDate.month &&
                          date.year == _selectedWeekDate.year;
                      final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

                      int weekdayIndex;
                      try {
                        weekdayIndex = date.weekday == 7 ? 0 : date.weekday;
                      } catch (e) {
                        weekdayIndex = 0;
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedWeekDate = date;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? ColorPalette.primary100.withOpacity(0.3) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? ColorPalette.primary100 : ColorPalette.bg300,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  weekdayNames[weekdayIndex],
                                  style: TextStyle(
                                    color: isSelected ? ColorPalette.text100 : ColorPalette.text200,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: isSelected ? ColorPalette.text100 : ColorPalette.text200,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // AI 추천 식단 배너
            InkWell(
              onTap: _navigateToRecipe,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ColorPalette.gradientYellow.withOpacity(0.1), ColorPalette.primary100.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorPalette.bg300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 추천 식단',
                      style: TextStyle(
                        color: ColorPalette.text100,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_userName님, 다음 식사는 $_lackingNutrient 보충을 위해 $_recommendedFood은(는) 어떤가요? 🥗',
                      style: const TextStyle(
                        color: ColorPalette.text100,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 영양소 분석 슬롯 (오늘 날짜일 때만 표시)
            if (_hasNutrientData && _isToday(_selectedWeekDate))
              SizedBox(
                height: 200,
                child: GridView.builder(
                  scrollDirection: Axis.vertical,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _nutrientSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _nutrientSlots[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColorPalette.primary100.withOpacity(0.2),
                        border: Border.all(color: ColorPalette.primary100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.name,
                            style: const TextStyle(
                              color: ColorPalette.text100,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${slot.current.toInt()}/${slot.target.toInt()}mg',
                            style: const TextStyle(
                              color: ColorPalette.text100,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 작은 프로그레스 바
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: ColorPalette.bg200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (slot.percent / 100).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ColorPalette.primary200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${slot.percent.toInt()}%',
                            style: const TextStyle(
                              color: Color(0xFF5BB5C8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else if (!_isToday(_selectedWeekDate))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '${_selectedWeekDate.month}월 ${_selectedWeekDate.day}일에는 아직 섭취한 영양소가 없습니다.',
                    style: const TextStyle(
                      color: ColorPalette.text200,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: const Center(
                  child: Text(
                    '오늘 아직 섭취한 영양소가 없습니다.',
                    style: TextStyle(
                      color: ColorPalette.text200,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            // 오늘의 식사 섹션
            const Text(
              '오늘의 식사',
              style: TextStyle(
                color: Color(0xFF000000),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.14,
              ),
            ),
            const SizedBox(height: 16),
            // 식사 기록 카드들 (오늘 날짜일 때만 데이터 표시)
            ...(_isToday(_selectedWeekDate)
                    ? _mealRecords
                    : _mealRecords.map((m) => MealRecord(mealType: m.mealType, hasRecord: false)))
                .map(
                  (meal) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealType,
                        style: const TextStyle(
                          color: Color(0xFF1D1B20),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMealCard(meal),
                    ],
                  ),
                ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/report'),
    );
  }

  Widget _buildMealCard(MealRecord meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: meal.hasRecord
              ? [ColorPalette.gradientYellow.withOpacity(0.1), ColorPalette.primary100.withOpacity(0.1)]
              : [ColorPalette.gradientYellow.withOpacity(0.05), ColorPalette.primary100.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.bg300),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              if (meal.hasRecord && meal.imagePath != null)
                Container(
                  width: 80,
                  height: 100,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: ColorPalette.bg200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorPalette.bg300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      meal.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFECE6F0),
                          child: const Icon(Icons.image, color: Color(0xFFCAC4D0)),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (meal.hasRecord && meal.menuText != null)
                      Text(
                        meal.menuText!,
                        style: const TextStyle(
                          color: Color(0xFF1D1B20),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.25,
                          height: 1.4,
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _navigateToMealRecord(meal.mealType),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.add_circle,
                              size: 20,
                              color: ColorPalette.text100,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '기록하기',
                              style: TextStyle(
                                color: ColorPalette.text100,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // 편집 아이콘을 오른쪽 상단에 배치
          if (meal.hasRecord)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => _navigateToMealRecord(meal.mealType),
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFF1D1B20),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}
