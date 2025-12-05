import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widget/bottom_bar_widget.dart';
import '../theme/color_palette.dart';
import '../api/ai_recipe_api.dart';
import '../api/member_api_service.dart';
import '../api/meal_api_service.dart';
import 'recipe_pages.dart';
import 'analysis_pages.dart';
import '../model/nutrient_type.dart';
import '../model/daily_nutrient_status.dart';

class MealRecord {
  final String mealType;
  final String? imagePath;
  final String? menuText;
  final bool hasRecord;
  final List<String>? foods; // 분석된 음식 목록

  MealRecord({
    required this.mealType,
    this.imagePath,
    this.menuText,
    required this.hasRecord,
    this.foods, // 분석된 음식 목록
  });
}

class NutrientSlot {
  final String name;
  final double current; // 현재 섭취량
  final double target; // 목표 섭취량
  final double percent; // 퍼센트
  final String unit; // 단위

  NutrientSlot({
    required this.name,
    required this.current,
    required this.target,
    required this.percent,
    required this.unit,
  });
}

class ReportScreen extends StatefulWidget {
  final String? initialMealType; // 홈 화면에서 식사 타입 선택 시 전달

  const ReportScreen({
    super.key,
    this.initialMealType,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();

  /// 홈 화면에서 사용할 영양소 비율 가져오기
  static Map<NutrientType, double> getNutrientProgress() {
    return _ReportScreenState._nutrientProgressMap;
  }

  /// 홈 화면에서 사용할 칼로리 목표량 가져오기
  static double getTargetCalorie() {
    return _ReportScreenState._targetCalorie;
  }

  /// 홈 화면에서 사용할 현재 칼로리 가져오기
  static double getCurrentCalorie() {
    return _ReportScreenState._currentCalorie;
  }
}

class _ReportScreenState extends State<ReportScreen> {
  // TODO: [SERVER] 사용자 정보는 서버에서 가져오기
  // TODO: [DB] 사용자 이름은 데이터베이스에서 조회
  String _userName = '사용자';
  int? _pregnancyWeek;

  late DateTime _selectedDate;
  late DateTime _selectedWeekDate; // 주간 달력에서 선택된 날짜
  late int _selectedMonth; // 현재 월로 초기화
  final PageController _weekPageController = PageController(initialPage: 1000); // 무한 스크롤을 위한 큰 초기값

  // DailyNutrientStatus 기반 영양소 데이터
  late DailyNutrientStatus _todayStatus;
  List<NutrientSlot> _nutrientSlots = []; // 빈 리스트로 초기화
  bool _hasNutrientData = true; // 기존 필드는 그대로 사용하되, 이제 실제 상태에 맞게 바꾸도록 준비
  Map<String, double>? _nutritionTargets; // API에서 가져온 영양소 권장량

  // 홈 화면에서 사용할 영양소 비율 (static으로 공유)
  static final Map<NutrientType, double> _nutrientProgressMap = {};
  static double _targetCalorie = 2000.0;
  static double _currentCalorie = 0.0;

  // AI 추천 레시피 관련 상태 변수
  String? _bannerMessageFromAi; // AI가 보내준 배너 문장
  List<RecipeData> _aiRecipes = []; // AI 추천 레시피 3개

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
    // _buildNutrientSlotsFromStatus()는 _loadUserInfoAndNutritionTargets() 완료 후 호출됨

    // 사용자 정보 및 영양소 권장량 로드 후 AI 추천 레시피 호출
    _loadUserInfoAndNutritionTargets().then((_) {
      // 영양소 권장량 로드 완료 후 AI 추천 레시피 호출
      _reloadDailyNutrientsForSelectedDate();
    });

    // 홈 화면에서 식사 타입 선택 시 해당 식사 타입으로 분석 화면 이동
    if (widget.initialMealType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToMealRecord(widget.initialMealType!);
      });
    }
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

  // 식사 기록 데이터 (DB에서 불러옴)
  List<MealRecord> _mealRecords = [
    MealRecord(mealType: '아침', hasRecord: false),
    MealRecord(mealType: '점심', hasRecord: false),
    MealRecord(mealType: '간식', hasRecord: false),
    MealRecord(mealType: '저녁', hasRecord: false),
  ];

  /// DB에서 식사 기록 불러오기
  Future<void> _loadMealRecords(String memberId, String date) async {
    try {
      final mealApiService = MealApiService.instance;
      final result = await mealApiService.getMeals(
        memberId: memberId,
        date: date,
      );

      if (result['success'] == true) {
        final meals = result['meals'] as List;

        // 식사 타입별로 초기화 (여러 식사 기록을 합치기 위해 리스트로 관리)
        final mealMap = <String, List<Map<String, dynamic>>>{
          '아침': [],
          '점심': [],
          '간식': [],
          '저녁': [],
        };

        // DB에서 불러온 meals를 타입별로 그룹화
        for (final mealData in meals) {
          final mealTime = mealData['meal_time'] as String;
          if (mealMap.containsKey(mealTime)) {
            mealMap[mealTime]!.add(mealData);
          }
        }

        // 각 식사 타입별로 모든 기록을 합쳐서 하나의 MealRecord로 만들기
        final finalMealMap = <String, MealRecord>{};
        for (final entry in mealMap.entries) {
          final mealTime = entry.key;
          final mealList = entry.value;

          if (mealList.isEmpty) {
            // 기록이 없으면 기본값
            finalMealMap[mealTime] = MealRecord(mealType: mealTime, hasRecord: false);
          } else {
            // 여러 식사 기록을 합치기
            final allFoods = <String>[];
            final allImages = <String>[];
            final allMemos = <String>[];

            for (final mealData in mealList) {
              final foods = mealData['foods'] as List? ?? [];
              final imageUrl = mealData['image_url'] as String?;
              final memo = mealData['memo'] as String? ?? '';

              // foods를 List<String>으로 변환하여 추가
              final foodsList = foods.map((f) => f.toString()).toList();
              allFoods.addAll(foodsList);

              if (imageUrl != null && imageUrl.isNotEmpty) {
                allImages.add(imageUrl);
              }
              if (memo.isNotEmpty) {
                allMemos.add(memo);
              }
            }

            // 첫 번째 이미지를 대표 이미지로 사용 (여러 개가 있으면 첫 번째 것)
            final representativeImage = allImages.isNotEmpty ? allImages.first : null;

            // 모든 음식 목록을 합쳐서 표시
            final combinedMenuText = allFoods.isNotEmpty
                ? allFoods.join(', ')
                : (allMemos.isNotEmpty ? allMemos.join(', ') : null);

            finalMealMap[mealTime] = MealRecord(
              mealType: mealTime,
              imagePath: representativeImage,
              menuText: combinedMenuText,
              hasRecord: true,
              foods: allFoods.isNotEmpty ? allFoods : null, // 모든 음식 목록
            );
          }
        }

        if (mounted) {
          setState(() {
            _mealRecords = [
              finalMealMap['아침']!,
              finalMealMap['점심']!,
              finalMealMap['간식']!,
              finalMealMap['저녁']!,
            ];
          });
          debugPrint(
            '✅ [ReportScreen] 식사 기록 로드 완료: ${meals.length}개 (아침: ${mealMap['아침']!.length}, 점심: ${mealMap['점심']!.length}, 간식: ${mealMap['간식']!.length}, 저녁: ${mealMap['저녁']!.length})',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ReportScreen] 식사 기록 로드 실패: $e');
      // 에러 발생 시 기본값 유지
    }
  }

  /// 임신 분기 계산 (1-13: 1분기, 14-27: 2분기, 28-40: 3분기)
  int _calculateTrimester(int pregnancyWeek) {
    if (pregnancyWeek >= 1 && pregnancyWeek <= 13) {
      return 1;
    } else if (pregnancyWeek >= 14 && pregnancyWeek <= 27) {
      return 2;
    } else if (pregnancyWeek >= 28 && pregnancyWeek <= 40) {
      return 3;
    }
    return 1; // 기본값
  }

  /// 사용자 정보 및 영양소 권장량 로드
  Future<void> _loadUserInfoAndNutritionTargets() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 사용자 건강 정보 가져오기
      try {
        final healthInfo = await MemberApiService.instance.getHealthInfo(user.uid);
        _userName = healthInfo['nickname'] as String? ?? '사용자';

        // preg_week를 직접 사용 (DB에서 가져온 값)
        _pregnancyWeek = healthInfo['pregWeek'] as int? ?? healthInfo['pregnancy_week'] as int?;
      } catch (e) {
        debugPrint('⚠️ [ReportScreen] 건강 정보 로드 실패: $e');
      }

      // 임신 주차가 있으면 영양소 권장량 가져오기
      if (_pregnancyWeek != null) {
        final trimester = _calculateTrimester(_pregnancyWeek!);
        try {
          final nutritionTarget = await MemberApiService.instance.getNutritionTarget(trimester);
          _nutritionTargets = Map<String, double>.from(
            nutritionTarget.map((key, value) => MapEntry(key, (value as num).toDouble())),
          );
          debugPrint(
            '✅ [ReportScreen] 영양소 권장량 로드 완료: trimester=$trimester, targets=${_nutritionTargets?.keys.toList()}',
          );

          // 영양소 슬롯 빌드 (권장량이 로드된 후)
          _buildNutrientSlotsFromStatus();
          debugPrint('✅ [ReportScreen] 영양소 슬롯 개수: ${_nutrientSlots.length}');

          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('⚠️ [ReportScreen] 영양소 권장량 로드 실패: $e');
          // 권장량 로드 실패 시에도 빈 슬롯 리스트로 초기화
          _nutrientSlots = [];
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        // 임신 주차가 없으면 빈 슬롯 리스트
        debugPrint('⚠️ [ReportScreen] 임신 주차 정보가 없어 영양소 권장량을 가져올 수 없습니다.');
        _nutrientSlots = [];
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ReportScreen] 사용자 정보 로드 실패: $e');
    }
  }

  /// DailyNutrientStatus로부터 NutrientSlot 리스트를 생성합니다.
  void _buildNutrientSlotsFromStatus() {
    // MemberNutritionTarget의 모든 영양소 필드
    final allNutrients = [
      'carb',
      'protein',
      'fat',
      'sodium',
      'iron',
      'folate',
      'calcium',
      'vitamin_d',
      'omega3',
      'sugar',
      'magnesium',
      'vitamin_a',
      'vitamin_b12',
      'vitamin_c',
      'dietary_fiber',
      'potassium',
    ];

    String _nameOf(String nutrientKey) {
      switch (nutrientKey) {
        case 'calories':
          return '칼로리';
        case 'carb':
          return '탄수화물';
        case 'protein':
          return '단백질';
        case 'fat':
          return '지방';
        case 'sodium':
          return '나트륨';
        case 'iron':
          return '철분';
        case 'folate':
          return '엽산';
        case 'calcium':
          return '칼슘';
        case 'vitamin_d':
          return '비타민D';
        case 'omega3':
          return '오메가3';
        case 'sugar':
          return '당';
        case 'magnesium':
          return '마그네슘';
        case 'vitamin_a':
          return '비타민A';
        case 'vitamin_b12':
          return '비타민B12';
        case 'vitamin_c':
          return '비타민C';
        case 'dietary_fiber':
          return '식이섬유';
        case 'potassium':
          return '칼륨';
        default:
          return nutrientKey;
      }
    }

    /// 영양소 단위 변환 함수
    String _getUnit(String nutrientKey) {
      switch (nutrientKey) {
        case 'calories':
          return 'kcal';
        case 'carb':
        case 'protein':
        case 'fat':
        case 'omega3':
        case 'sugar':
        case 'dietary_fiber':
          return 'g';
        case 'sodium':
        case 'iron':
        case 'calcium':
        case 'magnesium':
        case 'vitamin_c':
        case 'potassium':
          return 'mg';
        case 'folate':
        case 'vitamin_d':
        case 'vitamin_a':
        case 'vitamin_b12':
          return 'μg';
        default:
          return '';
      }
    }

    _nutrientSlots = allNutrients
        .map((nutrientKey) {
          // 권장량은 PostgreSQL DB에서 조회한 값만 사용 (필수)
          double target = 0;
          if (_nutritionTargets != null && _nutritionTargets!.containsKey(nutrientKey)) {
            target = _nutritionTargets![nutrientKey] ?? 0;
          }

          // 현재 섭취량은 DailyNutrientStatus에서 가져오기 (없으면 0)
          double current = 0;
          NutrientType? type;
          switch (nutrientKey) {
            case 'carb':
              type = NutrientType.carb;
              break;
            case 'protein':
              type = NutrientType.protein;
              break;
            case 'fat':
              type = NutrientType.fat;
              break;
            case 'sodium':
              type = NutrientType.sodium;
              break;
            case 'iron':
              type = NutrientType.iron;
              break;
            case 'folate':
              type = NutrientType.folate;
              break;
            case 'calcium':
              type = NutrientType.calcium;
              break;
            case 'vitamin_d':
              type = NutrientType.vitaminD;
              break;
            case 'omega3':
              type = NutrientType.omega3;
              break;
            // DailyNutrientStatus에 없는 영양소는 current = 0으로 유지
            case 'sugar':
            case 'magnesium':
            case 'vitamin_a':
            case 'vitamin_b12':
            case 'vitamin_c':
            case 'dietary_fiber':
            case 'potassium':
              current = 0; // 아직 DailyNutrientStatus에 없으므로 0
              break;
          }
          if (type != null) {
            current = _todayStatus.consumed[type] ?? 0;
          }

          // 권장량 달성율 계산 (0~200%)
          final percent = target > 0 ? ((current / target) * 100).clamp(0.0, 200.0) : 0.0;

          // 홈 화면에서 사용할 영양소 비율 맵 업데이트
          if (type != null) {
            _nutrientProgressMap[type] = percent;
          }

          return NutrientSlot(
            name: _nameOf(nutrientKey),
            current: current,
            target: target,
            percent: percent.toDouble(),
            unit: _getUnit(nutrientKey),
          );
        })
        .where((slot) => slot.target > 0)
        .toList(); // target이 0보다 큰 것만 표시 (PostgreSQL DB에서 조회한 권장량이 있는 것만)

    // 칼로리 정보 업데이트
    if (_nutritionTargets != null && _nutritionTargets!.containsKey('calories')) {
      _targetCalorie = (_nutritionTargets!['calories'] as num?)?.toDouble() ?? 2000.0;
    }
    _currentCalorie = _todayStatus.consumed[NutrientType.energy] ?? 0.0;
  }

  /// 선택된 날짜에 대한 일별 영양소 데이터를 다시 로드합니다.
  ///
  /// DB에서 선택된 날짜의 식사 기록 및 영양소 데이터를 불러옵니다.
  Future<void> _reloadDailyNutrientsForSelectedDate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ [ReportScreen] 사용자 로그인 정보가 없습니다.');
        _todayStatus = createDummyTodayStatus();
        _buildNutrientSlotsFromStatus();
        setState(() {
          _hasNutrientData = true;
        });
        return;
      }

      // 선택된 날짜를 YYYY-MM-DD 형식으로 변환
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // DB에서 해당 날짜의 영양소 데이터 가져오기
      final mealApiService = MealApiService.instance;
      final dailyNutrition = await mealApiService.getDailyNutrition(
        memberId: user.uid,
        date: dateStr,
      );

      if (dailyNutrition['success'] == true) {
        final totalNutrition = dailyNutrition['total_nutrition'] as Map<String, dynamic>;

        // DB에서 가져온 섭취량을 NutrientType Map으로 변환
        final consumed = <NutrientType, double>{
          NutrientType.energy: (totalNutrition['calories'] as num?)?.toDouble() ?? 0.0,
          NutrientType.carb: (totalNutrition['carbs'] as num?)?.toDouble() ?? 0.0,
          NutrientType.protein: (totalNutrition['protein'] as num?)?.toDouble() ?? 0.0,
          NutrientType.fat: (totalNutrition['fat'] as num?)?.toDouble() ?? 0.0,
          NutrientType.sodium: (totalNutrition['sodium'] as num?)?.toDouble() ?? 0.0,
          NutrientType.iron: (totalNutrition['iron'] as num?)?.toDouble() ?? 0.0,
          NutrientType.folate: (totalNutrition['folate'] as num?)?.toDouble() ?? 0.0,
          NutrientType.calcium: (totalNutrition['calcium'] as num?)?.toDouble() ?? 0.0,
          NutrientType.vitaminD: (totalNutrition['vitamin_d'] as num?)?.toDouble() ?? 0.0,
          NutrientType.omega3: (totalNutrition['omega3'] as num?)?.toDouble() ?? 0.0,
        };

        // 권장량은 _nutritionTargets에서 가져오기 (없으면 기본값 사용)
        final recommended = <NutrientType, double>{};
        if (_nutritionTargets != null) {
          recommended[NutrientType.energy] = _nutritionTargets!['calories'] ?? 2200.0;
          recommended[NutrientType.carb] = _nutritionTargets!['carbs'] ?? 260.0;
          recommended[NutrientType.protein] = _nutritionTargets!['protein'] ?? 70.0;
          recommended[NutrientType.fat] = _nutritionTargets!['fat'] ?? 70.0;
          recommended[NutrientType.sodium] = _nutritionTargets!['sodium'] ?? 2000.0;
          recommended[NutrientType.iron] = _nutritionTargets!['iron'] ?? 27.0;
          recommended[NutrientType.folate] = _nutritionTargets!['folate'] ?? 600.0;
          recommended[NutrientType.calcium] = _nutritionTargets!['calcium'] ?? 1000.0;
          recommended[NutrientType.vitaminD] = _nutritionTargets!['vitamin_d'] ?? 15.0;
          recommended[NutrientType.omega3] = _nutritionTargets!['omega3'] ?? 300.0;
        } else {
          // 권장량이 없으면 기본값 사용
          final defaultRec = defaultMidPregnancyConfig.perDay;
          recommended.addAll(defaultRec);
        }

        // DailyNutrientStatus 객체 생성
        _todayStatus = DailyNutrientStatus(
          consumed: consumed,
          recommended: recommended,
        );

        // 홈 화면에서 사용할 칼로리 업데이트
        _currentCalorie = consumed[NutrientType.energy] ?? 0.0;

        debugPrint('✅ [ReportScreen] DB에서 영양소 데이터 로드 완료: ${consumed[NutrientType.energy]} kcal');

        // 식사 기록 목록도 함께 불러오기
        await _loadMealRecords(user.uid, dateStr);
      } else {
        // 데이터가 없으면 더미 데이터 사용
        _todayStatus = createDummyTodayStatus();
        debugPrint('⚠️ [ReportScreen] 해당 날짜에 식사 기록이 없습니다.');

        // 식사 기록도 초기화
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _loadMealRecords(user.uid, dateStr);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ReportScreen] 영양소 데이터 로드 실패: $e');
      // 에러 발생 시 더미 데이터 사용
      _todayStatus = createDummyTodayStatus();
    }

    // _nutritionTargets가 로드되었는지 확인
    if (_nutritionTargets == null || _nutritionTargets!.isEmpty) {
      debugPrint('⚠️ [ReportScreen] 영양소 권장량이 아직 로드되지 않았습니다. AI 레시피 추천을 건너뜁니다.');
      setState(() {
        _hasNutrientData = true;
      });
      return;
    }

    _buildNutrientSlotsFromStatus();

    setState(() {
      _hasNutrientData = true; // TODO: 실제 데이터 없으면 false 처리
    });

    // 🔽 AI 추천 식단 호출 (백엔드 없어도 try/catch 때문에 앱이 깨지지 않아야 함)
    // _nutrientSlots에서 모든 영양소 데이터 추출하여 Map으로 변환
    final nutrientsMap = <String, Map<String, double>>{};

    // 영양소 이름(한글)을 영문 키로 매핑
    final nutrientKeyMap = {
      '칼로리': 'calories',
      '탄수화물': 'carbs',
      '단백질': 'protein',
      '지방': 'fat',
      '나트륨': 'sodium',
      '철분': 'iron',
      '엽산': 'folate',
      '칼슘': 'calcium',
      '비타민D': 'vitamin_d',
      '오메가3': 'omega3',
      '당': 'sugar',
      '마그네슘': 'magnesium',
      '비타민A': 'vitamin_a',
      '비타민B12': 'vitamin_b12',
      '비타민C': 'vitamin_c',
      '식이섬유': 'dietary_fiber',
      '칼륨': 'potassium',
    };

    for (final slot in _nutrientSlots) {
      final key = nutrientKeyMap[slot.name];
      if (key != null) {
        nutrientsMap[key] = {
          'current': slot.current,
          'ratio': slot.percent,
        };
      }
    }

    // 디버그: 추출된 영양소 데이터 확인
    debugPrint('✅ [ReportScreen] AI 레시피 추천 요청 - 영양소 개수: ${nutrientsMap.length}');
    nutrientsMap.forEach((key, value) {
      debugPrint('  - $key: current=${value['current']}, ratio=${value['ratio']}%');
    });

    final aiResp = await fetchAiRecommendedRecipes(
      nickname: _userName,
      week: _pregnancyWeek ?? 12,
      bmi: 22.0, // TODO: 실제 BMI로 교체
      conditions: '없음', // TODO: 실제 진단/질환 정보로 교체
      // report_pages.dart에서 계산된 모든 영양소 값 전달
      nutrients: nutrientsMap,
    );
    if (!mounted) return;
    setState(() {
      if (aiResp.bannerMessage.isNotEmpty) {
        _bannerMessageFromAi = aiResp.bannerMessage;
      }
      if (aiResp.recipes.isNotEmpty) {
        _aiRecipes = aiResp.recipes;
      }
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
      MaterialPageRoute(
        builder: (context) => RecipeScreen(
          initialMenuIndex: 0,
          // AI 레시피가 있으면 그것을 넘기고, 없으면 null → 기존 목 데이터 사용
          initialRecipes: _aiRecipes.isNotEmpty ? _aiRecipes : null,
        ),
      ),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisScreen(
          mealType: mealType,
          selectedDate: _selectedWeekDate,
          onAnalysisComplete: (Map<String, dynamic> result) async {
            // AnalysisScreen에서 분석 완료 후 콜백
            // DB에서 최신 영양소 데이터 다시 불러오기
            await _reloadDailyNutrientsForSelectedDate();
            // result: { imageUrl, menuText, mealType, selectedDate }
            final imageUrl = result['imageUrl'] as String?;
            final menuText = result['menuText'] as String?;
            final resultMealType = result['mealType'] as String? ?? mealType;

            // 해당 식사 타입의 MealRecord 업데이트
            setState(() {
              final index = _mealRecords.indexWhere((m) => m.mealType == resultMealType);
              if (index != -1) {
                // foods는 result에서 가져오거나 menuText에서 파싱
                final foodsList = result['foods'] as List<String>? ?? (menuText != null ? menuText.split(', ') : null);

                _mealRecords[index] = MealRecord(
                  mealType: resultMealType,
                  imagePath: imageUrl, // Firebase Storage URL 또는 로컬 경로
                  menuText: menuText,
                  hasRecord: true,
                  foods: foodsList,
                );
              }
            });
          },
        ),
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
                        child: Bounceable(
                          onTap: () {},
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
            Bounceable(
              onTap: () {},
              child: InkWell(
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
                        _bannerMessageFromAi ??
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
            ),
            const SizedBox(height: 30),
            // 영양소 분석 슬롯
            if (_isToday(_selectedWeekDate))
              // 오늘 날짜인 경우
              (_hasNutrientData != false)
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), // 자체 스크롤 비활성화
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ColorPalette.primary100.withOpacity(0.2),
                            border: Border.all(color: ColorPalette.primary100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slot.name == '오메가3'
                                    ? '${slot.current.toStringAsFixed(2)}${slot.unit}/${slot.target.toStringAsFixed(2)}${slot.unit}'
                                    : '${slot.current.toInt()}${slot.unit}/${slot.target.toInt()}${slot.unit}',
                                style: const TextStyle(
                                  color: ColorPalette.text100,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // 작은 프로그레스 바 (권장량 달성율)
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
                              const SizedBox(height: 2),
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
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: const Center(
                        child: Text(
                          '오늘 섭취한 영양소가 없습니다.',
                          style: TextStyle(
                            color: ColorPalette.text200,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    )
            else
              // 오늘 날짜가 아닌 경우
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '${_selectedWeekDate.month}월 ${_selectedWeekDate.day}일에 섭취한 영양소가 없습니다.',
                    style: const TextStyle(
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
        clipBehavior: Clip.none, // 웹에서도 아이콘이 잘리지 않도록
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
                    child: _buildMealImage(meal.imagePath!),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 분석된 음식 목록 표시 (사진 옆에)
                    if (meal.hasRecord && meal.foods != null && meal.foods!.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: meal.foods!.map((food) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ColorPalette.primary100.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ColorPalette.primary100.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              food,
                              style: const TextStyle(
                                color: Color(0xFF1D1B20),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else if (meal.hasRecord && meal.menuText != null)
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
                      Bounceable(
                        onTap: () => _navigateToMealRecord(meal.mealType),
                        child: Row(
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
          // 편집 아이콘을 오른쪽 상단에 배치 (웹에서도 보이도록 Material로 감싸기)
          if (meal.hasRecord)
            Positioned(
              top: -8,
              right: -8,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  // TODO: [AI] [DB] 편집 시 기존 분석 결과 수정 또는 재분석 기능
                  onPressed: () => _navigateToMealRecord(meal.mealType),
                  icon: const Icon(
                    Icons.edit,
                    color: Color(0xFF1D1B20),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: '편집',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 이미지 경로가 URL인지 로컬 경로인지 판단하여 적절한 위젯 반환
  Widget _buildMealImage(String imagePath) {
    // URL인지 확인 (http:// 또는 https://로 시작)
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFECE6F0),
            child: const Icon(Icons.image, color: Color(0xFFCAC4D0)),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFFECE6F0),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    } else if (imagePath.startsWith('assets/')) {
      // assets 경로인 경우
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFECE6F0),
            child: const Icon(Icons.image, color: Color(0xFFCAC4D0)),
          );
        },
      );
    } else {
      // 로컬 파일 경로인 경우
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFECE6F0),
            child: const Icon(Icons.image, color: Color(0xFFCAC4D0)),
          );
        },
      );
    }
  }
}
