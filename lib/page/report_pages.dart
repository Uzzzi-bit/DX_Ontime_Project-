import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widget/bottom_bar_widget.dart';
import 'recipe_pages.dart';

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
  final double? value;
  final Color backgroundColor;
  final Color borderColor;

  NutrientSlot({
    required this.name,
    this.value,
    required this.backgroundColor,
    required this.borderColor,
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
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = '12월';
  final String _lackingNutrient = '단백질, 비타민';
  final String _recommendedFood = '닭가슴살 샐러드';

  // 영양소 데이터 유무
  final bool _hasNutrientData = false; // true로 변경하면 영양소 카드 표시

  // 영양소 슬롯 데이터
  final List<NutrientSlot> _nutrientSlots = [
    NutrientSlot(
      name: 'slot',
      value: null,
      backgroundColor: const Color(0xFFEADDFF),
      borderColor: const Color(0xFF6750A4),
    ),
    NutrientSlot(
      name: 'slot',
      value: null,
      backgroundColor: const Color(0xFFEADDFF),
      borderColor: const Color(0xFF6750A4),
    ),
    NutrientSlot(
      name: 'slot',
      value: null,
      backgroundColor: const Color(0xFFEADDFF),
      borderColor: const Color(0xFF6750A4),
    ),
    NutrientSlot(
      name: 'slot',
      value: null,
      backgroundColor: const Color(0xFFEADDFF),
      borderColor: const Color(0xFF6750A4),
    ),
    NutrientSlot(
      name: 'slot',
      value: null,
      backgroundColor: const Color(0xFFEADDFF),
      borderColor: const Color(0xFF6750A4),
    ),
    NutrientSlot(
      name: 'slot',
      value: null,
      backgroundColor: const Color(0xFFEADDFF),
      borderColor: const Color(0xFF6750A4),
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
    // 일요일을 주의 시작으로 설정 (weekday: 7 -> 0으로 변환)
    final weekday = date.weekday == 7 ? 0 : date.weekday;
    final startOfWeek = date.subtract(Duration(days: weekday));
    for (int i = 0; i < 7; i++) {
      week.add(startOfWeek.add(Duration(days: i)));
    }
    return week;
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
        _selectedMonth = '${picked.month}월';
      });
    }
  }

  void _navigateToRecipe() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecipeScreen()),
    );
  }

  void _navigateToMealRecord(String mealType) {
    // TODO: 식단 등록 페이지로 이동
    print('식단 등록: $mealType');
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(_selectedDate);
    final dateFormat = DateFormat('M.d E', 'ko');
    final dateText = dateFormat.format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF1D1B20),
          ),
        ),
        title: Text(
          dateText,
          style: const TextStyle(
            color: Color(0xFF1D1B20),
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _selectDate,
            icon: const Icon(
              Icons.calendar_today,
              color: Color(0xFF2F2F2F),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 선택 섹션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedMonth,
                        style: const TextStyle(
                          color: Color(0xFF2F2F2F),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more,
                        size: 16,
                        color: const Color(0xFF2F2F2F),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _selectDate,
                  icon: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF2F2F2F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 주간 달력
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: weekDates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = weekDates[index];
                  final isToday =
                      date.day == DateTime.now().day &&
                      date.month == DateTime.now().month &&
                      date.year == DateTime.now().year;
                  final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                  final weekdayIndex = date.weekday == 7 ? 0 : date.weekday;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: Container(
                      width: 40,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFFD7F1FF).withOpacity(0.6) : Colors.transparent,
                        border: Border.all(
                          color: isToday ? const Color(0xFFD2ECBF).withOpacity(0.5) : const Color(0xFFE8E8E8),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayNames[weekdayIndex],
                            style: TextStyle(
                              color: isToday ? const Color(0xFF1E1E1E) : const Color(0xFF585555),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isToday ? const Color(0xFF1E1E1E) : const Color(0xFF585555),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBFCEF), Color(0xFFF1FAF9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0ECE4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 추천 식단',
                      style: TextStyle(
                        color: Color(0xFF000000),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_userName님, 다음 식사는 $_lackingNutrient 보충을 위해 $_recommendedFood은(는) 어떤가요? 🥗',
                      style: const TextStyle(
                        color: Color(0xFF000000),
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
            // 영양소 분석 슬롯
            if (_hasNutrientData)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _nutrientSlots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final slot = _nutrientSlots[index];
                    return Container(
                      width: 124,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: slot.backgroundColor,
                        border: Border.all(color: slot.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slot.name,
                            style: const TextStyle(
                              color: Color(0xFF6750A4),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (slot.value != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${slot.value}%',
                              style: const TextStyle(
                                color: Color(0xFF6750A4),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
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
                      color: Color(0xFF49454F),
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.14,
              ),
            ),
            const SizedBox(height: 16),
            // 식사 기록 카드들
            ..._mealRecords.map((meal) => _buildMealCard(meal)),
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
              ? [const Color(0xFFFBFCEF), const Color(0xFFF1FAF9)]
              : [const Color(0xFFF9FADE).withOpacity(0.5), const Color(0xFFE2F4F3).withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0ECE4)),
      ),
      child: Row(
        children: [
          if (meal.hasRecord && meal.imagePath != null)
            Container(
              width: 80,
              height: 100,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFECE6F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCAC4D0)),
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
                Text(
                  meal.mealType,
                  style: const TextStyle(
                    color: Color(0xFF1D1B20),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: 8),
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
                          color: Color(0xFF1D1B20),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '기록하기',
                          style: TextStyle(
                            color: Color(0xFF1D1B20),
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
    );
  }
}
