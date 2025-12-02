import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widget/bottom_bar_widget.dart';
import '../theme/color_palette.dart';
import 'recipe_pages.dart';
import 'analysis_pages.dart';
import '../model/nutrient_type.dart';
import '../model/daily_nutrient_status.dart';

class MealRecord {
  final String mealType;
  final String? imagePath;
  final String? menuText;
  final bool hasRecord;
  // TODO: [AI] AI 분석 결과 필드 추가 필요
  // final Map<String, dynamic>? analysisResult; // AI 분석 결과 (칼로리, 영양소 등)
  // final DateTime? recordedAt; // 기록 시간
  // final String? analysisId; // 분석 ID (서버에서 반환)

  MealRecord({
    required this.mealType,
    this.imagePath,
    this.menuText,
    required this.hasRecord,
    // TODO: [AI] 분석 결과 필드 추가
    // this.analysisResult,
    // this.recordedAt,
    // this.analysisId,
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
  // TODO: [SERVER] 사용자 정보는 서버에서 가져오기
  // TODO: [DB] 사용자 이름은 데이터베이스에서 조회
  final String _userName = '김레제';

  late DateTime _selectedDate;
  late DateTime _selectedWeekDate; // 주간 달력에서 선택된 날짜
  late int _selectedMonth; // 현재 월로 초기화
  final PageController _weekPageController = PageController(initialPage: 1000); // 무한 스크롤을 위한 큰 초기값

  // DailyNutrientStatus 기반 영양소 데이터
  late DailyNutrientStatus _todayStatus;
  late List<NutrientSlot> _nutrientSlots;
  bool _hasNutrientData = true; // 기존 필드는 그대로 사용하되, 이제 실제 상태에 맞게 바꾸도록 준비

  @override
  void initState() {
    super.initState();
    // 명시적으로 초기화
    final now = DateTime.now();
    _selectedDate = now;
    _selectedWeekDate = now;
    _selectedMonth = now.month;

    // TODO: [SERVER][DB] 나중에 API 연동으로 교체
    _todayStatus = createDummyTodayStatus();
    _buildNutrientSlotsFromStatus();
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  // TODO: [AI] AI 추천 시스템 연동
  // TODO: [DB] 부족한 영양소 정보는 데이터베이스에서 분석하여 가져오기
  final String _lackingNutrient = '단백질, 비타민';
  // TODO: [AI] AI가 추천하는 음식은 AI 서버에서 가져오기
  final String _recommendedFood = '닭가슴살 샐러드';

  // TODO: [DB] 식사 기록 데이터는 데이터베이스에서 조회
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

  /// DailyNutrientStatus로부터 NutrientSlot 리스트를 생성합니다.
  void _buildNutrientSlotsFromStatus() {
    // 리포트 화면에 보여줄 영양소 순서
    const displayOrder = <NutrientType>[
      NutrientType.carb,
      NutrientType.sodium,
      NutrientType.protein,
      NutrientType.fat,
      NutrientType.calcium,
      NutrientType.iron,
    ];

    String _nameOf(NutrientType type) {
      switch (type) {
        case NutrientType.carb:
          return '탄수화물';
        case NutrientType.sodium:
          return '나트륨';
        case NutrientType.protein:
          return '단백질';
        case NutrientType.fat:
          return '지방';
        case NutrientType.calcium:
          return '칼슘';
        case NutrientType.iron:
          return '철분';
        default:
          return type.toString();
      }
    }

    _nutrientSlots = displayOrder.map((type) {
      final current = _todayStatus.consumed[type] ?? 0;
      final target = _todayStatus.recommended[type] ?? 0;
      final ratio = _todayStatus.getProgress(type); // 0.0~2.0
      final percent = (ratio * 100).clamp(0, 200);

      return NutrientSlot(
        name: _nameOf(type),
        current: current,
        target: target,
        percent: percent.toDouble(),
      );
    }).toList();
  }

  /// 선택된 날짜에 대한 일별 영양소 데이터를 다시 로드합니다.
  ///
  /// 현재는 더미 데이터를 사용하지만, 나중에 API 연동 시
  /// userRepository.fetchDailyNutrients()를 통해 서버에서 데이터를 가져옵니다.
  Future<void> _reloadDailyNutrientsForSelectedDate() async {
    // TODO: [SERVER][DB] 실제 API 연동 시 userRepository를 통해 데이터 가져오기
    // 예시:
    // final result = await userRepository.fetchDailyNutrients(date: _selectedWeekDate);
    // if (result == null) {
    //   setState(() {
    //     _hasNutrientData = false;
    //   });
    //   return;
    // }
    // _todayStatus = result;
    // _buildNutrientSlotsFromStatus();
    // setState(() {
    //   _hasNutrientData = true;
    // });

    // 지금은 더미 데이터로 대체
    _todayStatus = createDummyTodayStatus();
    _buildNutrientSlotsFromStatus();

    setState(() {
      _hasNutrientData = true; // TODO: 실제 데이터 없으면 false 처리
    });
  }

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
        _selectedWeekDate = picked;
      });
      _reloadDailyNutrientsForSelectedDate();
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

  // TODO: [AI] [DB] 식사 기록 기능 구현
  //
  // [현재 흐름]
  // 1. 사용자가 "기록하기" 버튼 클릭 → AnalysisScreen으로 이동
  // 2. AnalysisScreen에서 사진 업로드 (카메라/앨범 선택)
  // 3. AI 이미지 분석 수행 (analysis_pages.dart의 _simulateImageAnalysis 참고)
  // 4. 분석된 음식 목록 확인 및 수정
  // 5. 영양소 분석 수행
  // 6. 분석 완료 후 리포트 화면으로 돌아옴
  //
  // [서버 연동 시 구현 필요 사항]
  // 1. AnalysisScreen에서 사진 선택 후:
  //    - 선택한 사진을 AI 서버에 전송
  //    - 예시 API: POST /api/analyze-meal-image
  //      Request: { image: File, mealType: String, date: DateTime }
  //      Response: {
  //        foods: [{ name, quantity, ... }], // AI가 인식한 음식 목록
  //        analysisId: string
  //      }
  //
  // 2. 사용자가 음식 목록 확인/수정 후 "분석하기" 버튼 클릭 시:
  //    - 최종 음식 목록을 AI 서버에 전송하여 영양소 분석 요청
  //    - 예시 API: POST /api/analyze-nutrients
  //      Request: {
  //        foods: [{ name, quantity, ... }],
  //        mealType: String,
  //        date: DateTime
  //      }
  //      Response: {
  //        calories: number,
  //        nutrients: { protein, carbs, fat, calcium, iron, ... },
  //        analysisResult: Object
  //      }
  //
  // 3. 분석 완료 후 데이터베이스 저장:
  //    - 분석된 사진을 서버에 업로드
  //    - 예시 API: POST /api/upload-meal-image
  //      Request: { image: File }
  //      Response: { imageUrl: String }
  //
  //    - 분석 결과와 함께 데이터베이스에 저장
  //    - 예시 API: POST /api/meal-records
  //      Request: {
  //        mealType: String,
  //        date: DateTime,
  //        imageUrl: String, // 업로드된 이미지 URL
  //        analysisResult: Object, // AI 분석 결과 (칼로리, 영양소 등)
  //        menuText: String // AI가 인식한 음식 목록 (쉼표로 구분)
  //      }
  //
  // 4. 리포트 화면 업데이트:
  //    - AnalysisScreen에서 Navigator.pop() 후
  //    - report_pages.dart의 _mealRecords를 데이터베이스에서 다시 조회
  //    - setState() 호출하여 UI 갱신
  //
  // 5. 에러 처리:
  //    - 사진 업로드 실패 시 처리
  //    - AI 분석 실패 시 처리
  //    - 네트워크 오류 처리
  //    - 사용자에게 적절한 에러 메시지 표시
  void _navigateToMealRecord(String mealType) {
    // TODO: [AI] [DB] AnalysisScreen에 mealType과 selectedDate 전달 필요
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => AnalysisScreen(
    //       mealType: mealType,
    //       selectedDate: _selectedWeekDate,
    //       onAnalysisComplete: (Map<String, dynamic> result) async {
    //         // AnalysisScreen에서 분석 완료 후 콜백
    //         // result: { imageUrl, analysisResult, menuText, ... }
    //
    //         // 1. 사진을 서버에 업로드
    //         // final imageUrl = await api.uploadMealImage(result['imagePath']);
    //
    //         // 2. 데이터베이스에 저장
    //         // await api.saveMealRecord(
    //         //   mealType: mealType,
    //         //   date: _selectedWeekDate,
    //         //   imageUrl: imageUrl,
    //         //   analysisResult: result['analysisResult'],
    //         //   menuText: result['menuText'],
    //         // );
    //
    //         // 3. 로컬 상태 업데이트
    //         // setState(() {
    //         //   _mealRecords = await api.getMealRecords(_selectedWeekDate);
    //         // });
    //       },
    //     ),
    //   ),
    // );
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
      _selectedDate = now;
    });
    // PageView를 오늘 주로 이동
    _weekPageController.jumpToPage(1000);
    _reloadDailyNutrientsForSelectedDate();
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(
                    border: Border.all(color: ColorPalette.bg300),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: DropdownButton<int>(
                    isDense: true,
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
                  _reloadDailyNutrientsForSelectedDate();
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
            // TODO: [AI] AI 추천 식단 배너 - AI 서버에서 추천 식단 정보를 가져와야 함
            // TODO: [DB] 부족한 영양소 정보는 데이터베이스에서 분석하여 가져오기
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
                    // TODO: [AI] AI가 생성한 추천 메시지는 AI 서버에서 가져오기
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
            const SizedBox(height: 30),
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
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _nutrientSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _nutrientSlots[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
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
                          const SizedBox(height: 6),
                          Text(
                            '${slot.current.toInt()}/${slot.target.toInt()}mg',
                            style: const TextStyle(
                              color: ColorPalette.text100,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
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
            // TODO: [DB] 선택된 날짜에 해당하는 식사 기록을 데이터베이스에서 조회
            // 식사 기록 카드들 (오늘 날짜일 때만 데이터 표시)
            // 예시: final mealRecords = await api.getMealRecords(_selectedWeekDate);
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
    // TODO: [AI] [DB] 분석 결과 표시 기능 추가
    // meal.analysisResult가 있을 경우:
    // - 칼로리 정보 표시
    // - 주요 영양소 정보 표시
    // - AI가 인식한 음식 목록 상세 표시
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
              // TODO: [DB] 저장된 사진은 서버 URL 또는 로컬 경로에서 가져오기
              // Image.asset 대신 Image.network 또는 Image.file 사용
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
                    // TODO: [AI] AI가 분석한 음식 목록 표시
                    // meal.analysisResult?.foods를 파싱하여 표시
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
                    // TODO: [AI] 분석 결과 추가 정보 표시 영역
                    // if (meal.analysisResult != null) ...[
                    //   const SizedBox(height: 8),
                    //   Text(
                    //     '칼로리: ${meal.analysisResult!['calories']}kcal',
                    //     style: TextStyle(...),
                    //   ),
                    //   // 영양소 정보 표시
                    // ],
                  ],
                ),
              ),
            ],
          ),
          // 편집 아이콘을 오른쪽 상단에 배치
          if (meal.hasRecord)
            Positioned(
              top: -16,
              right: -16,
              child: IconButton(
                // TODO: [AI] [DB] 편집 시 기존 분석 결과 수정 또는 재분석 기능
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
