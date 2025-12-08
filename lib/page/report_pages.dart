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
import '../api/recommendation_api_service.dart';
import '../api/body_measurement_api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
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

  /// 홈 화면에서 영양소 데이터 업데이트
  static void updateNutritionData({
    required double currentCalorie,
    required double targetCalorie,
    required Map<NutrientType, double> nutrientProgress,
  }) {
    _ReportScreenState._currentCalorie = currentCalorie;
    _ReportScreenState._targetCalorie = targetCalorie;
    _ReportScreenState._nutrientProgressMap.clear();
    _ReportScreenState._nutrientProgressMap.addAll(nutrientProgress);
  }
}

class _ReportScreenState extends State<ReportScreen> {
  // TODO: [SERVER] 사용자 정보는 서버에서 가져오기
  // TODO: [DB] 사용자 이름은 데이터베이스에서 조회
  String _userName = '사용자';
  int? _pregnancyWeek;
  double? _userHeightCm; // BMI 계산용
  double? _userWeightKg; // BMI 계산용
  String _userConditions = '없음'; // 진단/질환 정보
  List<String> _userAllergies = []; // 알러지 리스트

  late DateTime _selectedDate;
  late DateTime _selectedWeekDate; // 주간 달력에서 선택된 날짜
  late int _selectedMonth; // 현재 월로 초기화
  final PageController _weekPageController = PageController(initialPage: 1000); // 무한 스크롤을 위한 큰 초기값

  // DailyNutrientStatus 기반 영양소 데이터
  late DailyNutrientStatus _todayStatus;
  List<NutrientSlot> _nutrientSlots = []; // 빈 리스트로 초기화
  bool _hasNutrientData = true; // 기존 필드는 그대로 사용하되, 이제 실제 상태에 맞게 바꾸도록 준비
  Map<String, double>? _nutritionTargets; // API에서 가져온 영양소 권장량
  Map<String, dynamic>? _dailyNutritionFromDb; // DB에서 가져온 일별 영양소 데이터 (추가 영양소 포함)

  // 홈 화면에서 사용할 영양소 비율 (static으로 공유)
  static final Map<NutrientType, double> _nutrientProgressMap = {};
  static double _targetCalorie = 2000.0;
  static double _currentCalorie = 0.0;

  // AI 추천 레시피 관련 상태 변수
  String? _bannerMessageFromAi; // AI가 보내준 배너 문장
  List<RecipeData> _aiRecipes = []; // AI 추천 레시피 3개
  // 날짜별 레시피 및 배너 메시지 저장 (날짜를 키로 사용)
  final Map<String, String> _dateBannerMessages = {};
  final Map<String, List<RecipeData>> _dateAiRecipes = {};

  // 신체 변화 관련 상태 변수
  List<Map<String, dynamic>> _bodyMeasurements = []; // 신체 변화 측정 기록 (주간/월간)
  List<Map<String, dynamic>> _todayBodyMeasurements = []; // 선택된 날짜의 신체 변화 기록 (여러 개 가능: 아침/점심/저녁)

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
    _dailyNutritionFromDb = {}; // 빈 맵으로 초기화
    // _buildNutrientSlotsFromStatus()는 _loadUserInfoAndNutritionTargets() 완료 후 호출됨

    // 사용자 정보 및 영양소 권장량 로드 후 일별 영양소 데이터 로드
    // (AI 레시피는 _reloadDailyNutrientsForSelectedDate 내부에서 자동 호출됨)
    _loadUserInfoAndNutritionTargets().then((_) {
      _reloadDailyNutrientsForSelectedDate();
      _loadBodyMeasurements(); // 신체 변화 데이터 로드
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
        // 백엔드가 반환할 수 있는 meal_time 값들을 프론트엔드 표준 값으로 매핑
        String normalizeMealTime(String mealTime) {
          // 백엔드가 "조식", "중식", "석식", "야식" 또는 "아침", "점심", "간식", "저녁"을 반환할 수 있음
          final mapping = {
            '조식': '아침',
            '중식': '점심',
            '석식': '저녁',
            '야식': '간식',
            '아침': '아침',
            '점심': '점심',
            '간식': '간식',
            '저녁': '저녁',
          };
          return mapping[mealTime] ?? mealTime; // 매핑되지 않으면 원본 반환
        }

        for (final mealData in meals) {
          final rawMealTime = mealData['meal_time'] as String;
          final mealTime = normalizeMealTime(rawMealTime);
          if (mealMap.containsKey(mealTime)) {
            mealMap[mealTime]!.add(mealData);
          } else {
            // 매핑되지 않은 meal_time이 있으면 디버그 출력
            debugPrint('⚠️ [ReportScreen] 알 수 없는 meal_time: $rawMealTime');
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

      // 먼저 register_member API에서 닉네임 가져오기 (건강정보가 없어도 회원 정보는 있음)
      try {
        final memberInfo = await MemberApiService.instance.registerMember(
          user.uid,
          email: user.email,
        );
        _userName = memberInfo['nickname'] as String? ?? '사용자';
        debugPrint('✅ [ReportScreen] register_member에서 닉네임: $_userName');
      } catch (e) {
        debugPrint('⚠️ [ReportScreen] register_member 호출 실패: $e');
      }

      // 사용자 건강 정보 가져오기
      try {
        final healthInfo = await MemberApiService.instance.getHealthInfo(user.uid);
        // 닉네임이 없으면 건강정보에서 가져오기
        if (_userName == '사용자' || _userName.isEmpty) {
          _userName = healthInfo['nickname'] as String? ?? '사용자';
        }

        // preg_week를 직접 사용 (DB에서 가져온 값)
        _pregnancyWeek = healthInfo['pregWeek'] as int? ?? healthInfo['pregnancy_week'] as int?;

        // BMI 계산을 위한 체중/신장 정보 저장
        // Django의 DecimalField는 num, String, 또는 Decimal 객체로 올 수 있음
        final heightCmRaw = healthInfo['heightCm'];
        final weightKgRaw = healthInfo['weightKg'];

        double? heightCm;
        double? weightKg;

        // heightCm 변환 (num, String, Decimal 모두 처리)
        if (heightCmRaw != null) {
          if (heightCmRaw is num) {
            heightCm = heightCmRaw.toDouble();
          } else if (heightCmRaw is String) {
            heightCm = double.tryParse(heightCmRaw);
          } else {
            // Decimal 객체인 경우 toString() 후 파싱
            heightCm = double.tryParse(heightCmRaw.toString());
          }
        }

        // weightKg 변환 (num, String, Decimal 모두 처리)
        if (weightKgRaw != null) {
          if (weightKgRaw is num) {
            weightKg = weightKgRaw.toDouble();
          } else if (weightKgRaw is String) {
            weightKg = double.tryParse(weightKgRaw);
          } else {
            // Decimal 객체인 경우 toString() 후 파싱
            weightKg = double.tryParse(weightKgRaw.toString());
          }
        }

        final hasGdm = healthInfo['hasGestationalDiabetes'] as bool? ?? false;
        final allergiesList =
            (healthInfo['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

        // 디버그: 가져온 건강 정보 확인
        debugPrint('🔍 [ReportScreen] 건강 정보 로드:');
        debugPrint('  - heightCm (raw): $heightCmRaw, (parsed): $heightCm');
        debugPrint('  - weightKg (raw): $weightKgRaw, (parsed): $weightKg');
        debugPrint('  - hasGestationalDiabetes: $hasGdm');
        debugPrint('  - allergies: $allergiesList');

        // 클래스 변수에 저장 (AI 레시피 추천 시 사용)
        _userHeightCm = heightCm;
        _userWeightKg = weightKg;
        _userConditions = hasGdm ? '임신성 당뇨' : '없음';
        _userAllergies = allergiesList;
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

    _nutrientSlots =
        allNutrients
            .map((nutrientKey) {
              // 권장량은 PostgreSQL DB에서 조회한 값만 사용 (필수)
              double target = 0;
              if (_nutritionTargets != null && _nutritionTargets!.containsKey(nutrientKey)) {
                target = _nutritionTargets![nutrientKey] ?? 0;
              }

              // 현재 섭취량은 DB에서 직접 가져오기 (세부 영양소 포함)
              double current = 0;
              NutrientType? type;

              // DB에서 직접 가져온 값 사용 (세부 영양소 포함)
              // DB 키와 nutrientKey 매핑
              String dbKey = nutrientKey;
              if (nutrientKey == 'carb') {
                dbKey = 'carbs';
              } else if (nutrientKey == 'vitamin_b12') {
                dbKey = 'vitamin_b'; // DB에는 vitamin_b로 저장됨
              }

              if (_dailyNutritionFromDb != null && _dailyNutritionFromDb!.containsKey(dbKey)) {
                final dbValue = _dailyNutritionFromDb![dbKey];
                if (dbValue != null) {
                  current = (dbValue as num).toDouble();
                }
              } else if (_dailyNutritionFromDb != null && _dailyNutritionFromDb!.containsKey(nutrientKey)) {
                final dbValue = _dailyNutritionFromDb![nutrientKey];
                if (dbValue != null) {
                  current = (dbValue as num).toDouble();
                }
              } else {
                // DB에 없으면 DailyNutrientStatus에서 가져오기
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
                  default:
                    current = 0;
                    break;
                }
                if (type != null) {
                  current = _todayStatus.consumed[type] ?? 0;
                }
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
            .where((slot) => slot.target > 0 && slot.percent > 0) // target이 0보다 크고 percent가 0보다 큰 것만 표시
            .toList()
          ..sort((a, b) => b.percent.compareTo(a.percent)); // percent 기준 내림차순 정렬

    // 칼로리 정보 업데이트
    if (_nutritionTargets != null && _nutritionTargets!.containsKey('calories')) {
      _targetCalorie = (_nutritionTargets!['calories'] as num?)?.toDouble() ?? 2000.0;
    }
    _currentCalorie = _todayStatus.consumed[NutrientType.energy] ?? 0.0;
  }

  /// 선택된 날짜에 대한 일별 영양소 데이터를 다시 로드합니다.
  ///
  /// DB에서 선택된 날짜의 식사 기록 및 영양소 데이터를 불러옵니다.
  /// [shouldFetchRecipes]가 true이면 meal 데이터 추가로 인한 호출로 간주하여 API 호출
  Future<void> _reloadDailyNutrientsForSelectedDate({bool shouldFetchRecipes = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ [ReportScreen] 사용자 로그인 정보가 없습니다.');
        _todayStatus = createDummyTodayStatus();
        _dailyNutritionFromDb = {}; // 빈 맵으로 초기화
        _buildNutrientSlotsFromStatus();
        if (mounted) {
          setState(() {
            _hasNutrientData = true;
          });
        }
        return;
      }

      // 선택된 날짜를 YYYY-MM-DD 형식으로 변환
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // DB에서 해당 날짜의 레시피 불러오기 (영양소 데이터 로드 전에)
      await _loadRecommendationsFromDb(user.uid, dateStr);

      // DB에서 해당 날짜의 영양소 데이터 가져오기
      final mealApiService = MealApiService.instance;
      final dailyNutrition = await mealApiService.getDailyNutrition(
        memberId: user.uid,
        date: dateStr,
      );

      if (dailyNutrition['success'] == true) {
        final totalNutrition = dailyNutrition['total_nutrition'] as Map<String, dynamic>;

        // DB에서 가져온 모든 영양소 데이터 저장 (세부 영양소 포함)
        // Map<String, dynamic>으로 저장 (타입 변환은 사용 시점에 수행)
        _dailyNutritionFromDb = Map<String, dynamic>.from(totalNutrition);

        // 디버그: DB에서 가져온 영양소 데이터 확인
        debugPrint('📊 [ReportScreen] DB에서 가져온 영양소 데이터:');
        debugPrint('   calories: ${totalNutrition['calories']}');
        debugPrint('   carbs: ${totalNutrition['carbs']}');
        debugPrint('   protein: ${totalNutrition['protein']}');
        debugPrint('   fat: ${totalNutrition['fat']}');
        debugPrint('   iron: ${totalNutrition['iron']}');
        debugPrint('   calcium: ${totalNutrition['calcium']}');
        debugPrint('   omega3: ${totalNutrition['omega3']}');
        debugPrint('   전체 데이터: $totalNutrition');

        // DB에서 가져온 섭취량을 NutrientType Map으로 변환
        // 모든 영양소를 포함하되, DB에 없는 것은 0.0으로 설정
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

        // DB에서 가져온 추가 영양소도 저장 (AI 레시피 추천 시 사용)
        // 이 값들은 나중에 nutrientsMap 생성 시 사용됨
        _dailyNutritionFromDb = totalNutrition;

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

        // 영양소 데이터 표시 업데이트
        _buildNutrientSlotsFromStatus();
        if (mounted) {
          setState(() {
            _hasNutrientData = true;
          });
        }

        // AI 레시피 추천 호출 조건 확인 (meal 데이터 추가 시에만 호출)
        if (shouldFetchRecipes) {
          // meal 데이터 추가 시
          debugPrint('🍽️ [ReportScreen] Meal 데이터 추가 감지 - AI 레시피 추천 API 호출');
          await _fetchAiRecommendedRecipes();
        }
      } else {
        // 데이터가 없으면 더미 데이터 사용
        _todayStatus = createDummyTodayStatus();
        _dailyNutritionFromDb = null; // DB 데이터 없음
        debugPrint('⚠️ [ReportScreen] 해당 날짜에 식사 기록이 없습니다.');

        // 식사 기록도 초기화
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _loadMealRecords(user.uid, dateStr);
        }

        // 영양소 데이터 표시 업데이트
        _buildNutrientSlotsFromStatus();
        if (mounted) {
          setState(() {
            _hasNutrientData = true;
          });
        }

        // AI 레시피 추천 호출 조건 확인 (meal 데이터 추가 시에만 호출)
        if (shouldFetchRecipes) {
          // meal 데이터 추가 시
          debugPrint('🍽️ [ReportScreen] Meal 데이터 추가 감지 (데이터 없음) - AI 레시피 추천 API 호출');
          await _fetchAiRecommendedRecipes();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ReportScreen] 영양소 데이터 로드 실패: $e');
      // 에러 발생 시 더미 데이터 사용
      _todayStatus = createDummyTodayStatus();
      _dailyNutritionFromDb = {}; // 빈 맵으로 초기화
    }

    // _nutritionTargets가 로드되었는지 확인
    if (_nutritionTargets == null || _nutritionTargets!.isEmpty) {
      debugPrint('⚠️ [ReportScreen] 영양소 권장량이 아직 로드되지 않았습니다. AI 레시피 추천을 건너뜁니다.');
      if (mounted) {
        setState(() {
          _hasNutrientData = true;
        });
      }
      return;
    }

    _buildNutrientSlotsFromStatus();

    if (mounted) {
      setState(() {
        _hasNutrientData = true; // TODO: 실제 데이터 없으면 false 처리
      });
    }
  }

  /// AI 레시피 추천 API 호출 함수 (meal 데이터 추가 시 호출)
  Future<void> _fetchAiRecommendedRecipes() async {
    // 영양소 권장량이 없으면 건너뛰기
    if (_nutritionTargets == null || _nutritionTargets!.isEmpty) {
      debugPrint('⚠️ [ReportScreen] 영양소 권장량이 없어 AI 레시피 추천을 건너뜁니다.');
      return;
    }

    // 모든 영양소 데이터를 _todayStatus와 _nutritionTargets에서 직접 추출
    final nutrientsMap = <String, Map<String, double>>{};

    // 프롬프트에서 필요한 모든 영양소 목록 (섭취량이 0이어도 포함)
    final allNutrients = [
      'calories',
      'carbs',
      'protein',
      'fat',
      'sugar',
      'sodium',
      'calcium',
      'iron',
      'folate',
      'magnesium',
      'omega3',
      'vitamin_a',
      'vitamin_b12', // 프롬프트는 vitamin_b지만 DB는 vitamin_b12
      'vitamin_c',
      'vitamin_d',
      'dietary_fiber',
      'potassium',
    ];

    // NutrientType과 API 키 매핑
    final nutrientTypeToKey = {
      NutrientType.energy: 'calories',
      NutrientType.carb: 'carbs',
      NutrientType.protein: 'protein',
      NutrientType.fat: 'fat',
      NutrientType.sodium: 'sodium',
      NutrientType.iron: 'iron',
      NutrientType.folate: 'folate',
      NutrientType.calcium: 'calcium',
      NutrientType.vitaminD: 'vitamin_d',
      NutrientType.omega3: 'omega3',
      NutrientType.vitaminB: 'vitamin_b12', // vitaminB를 vitamin_b12로 매핑
    };

    // _todayStatus.consumed에서 섭취량 가져오기
    final consumed = _todayStatus.consumed;
    final recommended = _todayStatus.recommended;

    // 모든 영양소에 대해 데이터 생성 (섭취량이 0이어도 포함)
    for (final nutrientKey in allNutrients) {
      double current = 0.0;
      double target = 0.0;
      double ratio = 0.0;

      // NutrientType에서 찾기
      NutrientType? nutrientType;
      for (final entry in nutrientTypeToKey.entries) {
        if (entry.value == nutrientKey) {
          nutrientType = entry.key;
          break;
        }
      }

      if (nutrientType != null) {
        // _todayStatus에서 가져오기
        current = consumed[nutrientType] ?? 0.0;
        target = recommended[nutrientType] ?? 0.0;
      } else {
        // NutrientType에 없는 영양소는 _nutritionTargets와 _dailyNutritionFromDb에서 가져오기
        if (_nutritionTargets != null) {
          // DB 키 이름 매핑 (DB는 snake_case, API는 camelCase)
          final dbKey = nutrientKey == 'vitamin_b12' ? 'vitamin_b12' : nutrientKey;
          target = _nutritionTargets![dbKey] ?? 0.0;

          // 섭취량은 DB에서 가져온 dailyNutrition에서 찾기
          if (_dailyNutritionFromDb != null) {
            final dbValue = _dailyNutritionFromDb![dbKey];
            if (dbValue != null) {
              current = (dbValue as num).toDouble();
            }
          }
        }
      }

      // 비율 계산 (목표 대비)
      if (target > 0) {
        ratio = (current / target) * 100.0;
      }

      // 모든 영양소를 맵에 추가 (섭취량이 0이어도 포함)
      nutrientsMap[nutrientKey] = {
        'current': current,
        'ratio': ratio,
      };
    }

    // 디버그: 추출된 영양소 데이터 확인
    debugPrint('✅ [ReportScreen] AI 레시피 추천 요청 - 영양소 개수: ${nutrientsMap.length}');
    nutrientsMap.forEach((key, value) {
      debugPrint('  - $key: current=${value['current']}, ratio=${value['ratio']}%');
    });

    // BMI 계산 및 건강 정보 준비
    final weight = _userWeightKg ?? 60.0; // 기본값 60kg
    final height = _userHeightCm ?? 160.0; // 기본값 160cm
    final conditions = _userConditions;
    final allergies = _userAllergies;

    // 디버그: AI 레시피 추천에 사용되는 값 확인
    debugPrint('🔍 [ReportScreen] AI 레시피 추천 - 사용자 정보:');
    debugPrint('  - weight: $weight kg (저장된 값: $_userWeightKg)');
    debugPrint('  - height: $height cm (저장된 값: $_userHeightCm)');
    debugPrint('  - conditions: $conditions');
    debugPrint('  - allergies: $allergies');

    try {
      // 사용자 정보 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ [ReportScreen] 사용자 로그인 정보가 없습니다.');
        return;
      }

      final aiResp = await fetchAiRecommendedRecipes(
        nickname: _userName,
        week: _pregnancyWeek ?? 12,
        weight: weight,
        height: height,
        conditions: conditions,
        allergies: allergies,
        // report_pages.dart에서 계산된 모든 영양소 값 전달
        nutrients: nutrientsMap,
      );
      if (!mounted) return;

      // 현재 선택된 날짜
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      setState(() {
        if (aiResp.bannerMessage.isNotEmpty) {
          _bannerMessageFromAi = aiResp.bannerMessage;
          // 날짜별 배너 메시지 맵에 저장
          _dateBannerMessages[dateStr] = aiResp.bannerMessage;
          debugPrint('✅ [ReportScreen] AI 추천 식단 배너 메시지 저장: $dateStr');
        }
        if (aiResp.recipes.isNotEmpty) {
          _aiRecipes = aiResp.recipes;
          // 날짜별 레시피 맵에 저장 (중요: 이전 레시피를 새로운 것으로 덮어쓰기)
          _dateAiRecipes[dateStr] = _aiRecipes;
          // 전역 상태에 최신 AI 레시피 저장 (RecipeScreen이 자동으로 업데이트됨)
          RecipeScreen.setLatestAiRecipes(_aiRecipes);
          debugPrint('✅ [ReportScreen] AI 레시피 ${_aiRecipes.length}개 수신 완료 및 날짜별 맵에 저장: $dateStr');

          // DB에 레시피 저장 (비동기로 실행, 실패해도 화면은 업데이트)
          _saveRecommendationsToDb(user.uid, dateStr, aiResp.bannerMessage, _aiRecipes);
        } else {
          debugPrint('⚠️ [ReportScreen] AI 레시피가 비어있습니다.');
        }
      });
    } catch (e) {
      debugPrint('❌ [ReportScreen] AI 레시피 추천 실패: $e');
      // 에러 발생 시에도 앱이 깨지지 않도록 빈 리스트 유지
    }
  }

  /// AI 추천 레시피를 DB에 저장
  Future<void> _saveRecommendationsToDb(
    String memberId,
    String dateStr,
    String bannerMessage,
    List<RecipeData> recipes,
  ) async {
    try {
      await RecommendationApiService.instance.saveRecommendations(
        memberId: memberId,
        recommendationDate: dateStr,
        bannerMessage: bannerMessage,
        recipes: recipes,
      );
      debugPrint('✅ [ReportScreen] 레시피 DB 저장 완료: $dateStr');
    } catch (e) {
      debugPrint('⚠️ [ReportScreen] 레시피 DB 저장 실패: $e');
      // DB 저장 실패해도 화면은 업데이트되므로 에러만 로그
    }
  }

  /// DB에서 해당 날짜의 레시피 불러오기
  Future<void> _loadRecommendationsFromDb(String memberId, String dateStr) async {
    try {
      final result = await RecommendationApiService.instance.getRecommendations(
        memberId: memberId,
        date: dateStr,
      );

      if (result['success'] == true && result['recipes_count'] > 0) {
        final recipesJson = result['recipes'] as List<dynamic>;
        final recipes = recipesJson
            .map((json) => RecipeData.fromJson(json as Map<String, dynamic>))
            .where((recipe) => recipe.title.isNotEmpty) // 유효한 레시피만
            .toList();

        if (mounted && recipes.isNotEmpty) {
          final bannerMessage = result['banner_message'] as String? ?? '';
          setState(() {
            _bannerMessageFromAi = bannerMessage;
            _aiRecipes = recipes;
            // 날짜별 레시피 맵에 저장 (DB에서 로드한 최신 데이터)
            _dateAiRecipes[dateStr] = recipes;
            // 날짜별 배너 메시지 맵에 저장
            if (bannerMessage.isNotEmpty) {
              _dateBannerMessages[dateStr] = bannerMessage;
            }
            RecipeScreen.setLatestAiRecipes(_aiRecipes);
          });
          debugPrint('✅ [ReportScreen] DB에서 레시피 로드 완료: $dateStr, 레시피 ${recipes.length}개 (날짜별 맵에 저장)');
        }
      } else {
        debugPrint('⚠️ [ReportScreen] DB에 저장된 레시피 없음: $dateStr');
        // 저장된 레시피가 없으면 기본값 유지
      }
    } catch (e) {
      debugPrint('⚠️ [ReportScreen] DB에서 레시피 로드 실패: $e');
      // 로드 실패해도 기본값 사용
    }
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
    // 커스텀 캘린더 다이얼로그 표시 (다이얼로그 내부에서 기록 로드)
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CustomCalendarDialog(
        initialDate: _selectedDate,
        memberId: FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedMonth = picked.month;
        _selectedWeekDate = picked;
      });
      _reloadDailyNutrientsForSelectedDate();
      _loadBodyMeasurements(); // 신체 변화 데이터도 다시 로드
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
    // 해당 식사 타입의 기존 음식 목록 가져오기
    final existingMealRecord = _mealRecords.firstWhere(
      (meal) => meal.mealType == mealType,
      orElse: () => MealRecord(mealType: mealType, hasRecord: false),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisScreen(
          mealType: mealType,
          selectedDate: _selectedDate, // 실제 선택된 날짜 사용
          existingFoods: existingMealRecord.hasRecord ? (existingMealRecord.foods ?? []) : null,
          onAnalysisComplete: (Map<String, dynamic> result) async {
            // AnalysisScreen에서 분석 완료 후 콜백
            // DB에서 최신 영양소 데이터 다시 불러오기 (meal 데이터 추가로 인한 호출)
            await _reloadDailyNutrientsForSelectedDate(shouldFetchRecipes: true);
            // result: { imageUrl, menuText, mealType, selectedDate }
            final imageUrl = result['imageUrl'] as String?;
            final menuText = result['menuText'] as String?;
            final resultMealType = result['mealType'] as String? ?? mealType;

            // 해당 식사 타입의 MealRecord 업데이트
            if (mounted) {
              setState(() {
                final index = _mealRecords.indexWhere((m) => m.mealType == resultMealType);
                if (index != -1) {
                  // foods는 result에서 가져오거나 menuText에서 파싱
                  final foodsList =
                      result['foods'] as List<String>? ?? (menuText != null ? menuText.split(', ') : null);

                  _mealRecords[index] = MealRecord(
                    mealType: resultMealType,
                    imagePath: imageUrl, // Firebase Storage URL 또는 로컬 경로
                    menuText: menuText,
                    hasRecord: true,
                    foods: foodsList,
                  );
                }
              });
            }
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
                    if (!_isToday(_selectedDate))
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
                    if (!_isToday(_selectedDate)) const SizedBox(width: 8),
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
                    // PageView가 변경될 때는 주간 시작일로 설정하고, 첫 번째 날짜(월요일)를 선택
                    _selectedWeekDate = weekStart;
                    _selectedDate = weekStart; // 주간 시작일을 선택된 날짜로 설정
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
                                _selectedDate = date; // 실제 선택된 날짜 업데이트
                                _selectedWeekDate = date;
                              });
                              // 날짜 선택 시 해당 날짜의 데이터 로드
                              _reloadDailyNutrientsForSelectedDate();
                              _loadBodyMeasurements(); // 신체 변화 데이터도 함께 로드
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
            const SizedBox(height: 15),
            Text(
              '영양소 분석',
              style: TextStyle(
                color: ColorPalette.text100,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 15),
            // 영양소 분석 슬롯
            // 선택된 날짜의 데이터를 표시 (오늘인지 여부와 관계없이)
            (_hasNutrientData != false && _nutrientSlots.isNotEmpty)
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

                      // 섭취 권장량 기준으로 progress bar와 텍스트 색상 결정
                      // 배경색과 테두리는 primary 계열로 고정
                      Color progressBarColor;
                      Color percentTextColor;

                      if (slot.percent >= 150) {
                        progressBarColor = Colors.red;
                        percentTextColor = Colors.red;
                      } else if (slot.percent >= 100) {
                        progressBarColor = Colors.green;
                        percentTextColor = Colors.green;
                      } else {
                        progressBarColor = ColorPalette.primary200;
                        percentTextColor = Color(0xFF5BB5C8);
                      }

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
                                    color: progressBarColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${slot.percent.toInt()}%',
                              style: TextStyle(
                                color: percentTextColor,
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
                    child: Center(
                      child: Text(
                        _isToday(_selectedDate)
                            ? '오늘 섭취한 영양소가 없습니다.'
                            : '${_selectedDate.month}월 ${_selectedDate.day}일에 섭취한 영양소가 없습니다.',
                        style: const TextStyle(
                          color: ColorPalette.text200,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 32),
            // 신체 변화 섹션
            _buildBodyMeasurementSection(),
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
            // 선택된 날짜의 식사 기록 표시 (오늘인지 여부와 관계없이)
            ..._mealRecords.map(
              (meal) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      if (meal.hasRecord)
                        Material(
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
                    ],
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
      child: Row(
        children: [
          // TODO: [DB] 저장된 사진은 서버 URL 또는 로컬 경로에서 가져오기
          // Image.asset 대신 Image.network 또는 Image.file 사용
          // 이미지 표시 숨김 (기능은 유지 - DB 저장, 분석 등은 정상 작동)
          // if (meal.hasRecord && meal.imagePath != null)
          //   Container(
          //     width: 80,
          //     height: 100,
          //     margin: const EdgeInsets.only(right: 16),
          //     decoration: BoxDecoration(
          //       color: ColorPalette.bg200,
          //       borderRadius: BorderRadius.circular(8),
          //       border: Border.all(color: ColorPalette.bg300),
          //     ),
          //     child: ClipRRect(
          //       borderRadius: BorderRadius.circular(8),
          //       child: _buildMealImage(meal.imagePath!),
          //     ),
          //   ),
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

  /// 신체 변화 데이터 로드
  Future<void> _loadBodyMeasurements() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 선택된 날짜의 신체 변화 기록 조회 (여러 개 가능)
      final bodyMeasurementApi = BodyMeasurementApiService.instance;
      final todayResult = await bodyMeasurementApi.getBodyMeasurementByDate(
        memberId: user.uid,
        date: dateStr,
      );

      if (todayResult['success'] == true) {
        final measurements = todayResult['measurements'] as List<dynamic>? ?? [];
        _todayBodyMeasurements = measurements.map((m) => m as Map<String, dynamic>).toList();
      } else {
        _todayBodyMeasurements = [];
      }

      // 주간 데이터 조회 (현재 주: 월요일~일요일)
      // 선택된 날짜가 속한 주의 월요일과 일요일 계산 (시간 제거하여 정확한 날짜만 사용)
      final selectedDate = _selectedDate;
      final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final weekday = selectedDateOnly.weekday; // 1=월요일, 7=일요일
      final monday = selectedDateOnly.subtract(Duration(days: weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      final mondayStr = DateFormat('yyyy-MM-dd').format(monday);
      final sundayStr = DateFormat('yyyy-MM-dd').format(sunday);

      final weekResult = await bodyMeasurementApi.getBodyMeasurements(
        memberId: user.uid,
        startDate: mondayStr,
        endDate: sundayStr,
      );

      if (weekResult['success'] == true) {
        _bodyMeasurements =
            (weekResult['measurements'] as List<dynamic>?)?.map((m) => m as Map<String, dynamic>).toList() ?? [];
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ [ReportScreen] 신체 변화 데이터 로드 실패: $e');
    }
  }

  /// 신체 변화 섹션 빌드
  Widget _buildBodyMeasurementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '신체 변화',
              style: TextStyle(
                color: ColorPalette.text100,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: ColorPalette.primary200),
              onPressed: _showBodyMeasurementDialog,
              tooltip: '신체 변화 기록 추가',
            ),
          ],
        ),
        const SizedBox(height: 15),
        // 오늘의 신체 변화 기록 (아침/점심/저녁 구분)
        if (_todayBodyMeasurements.isNotEmpty)
          ..._todayBodyMeasurements.map(
            (measurement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBodyMeasurementCard(measurement),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ColorPalette.bg200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorPalette.bg300),
            ),
            child: Center(
              child: Text(
                '${_selectedDate.month}월 ${_selectedDate.day}일의 신체 변화 기록이 없습니다.',
                style: const TextStyle(
                  color: ColorPalette.text200,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        // 주간 체중/혈당 추이 그래프
        if (_bodyMeasurements.isNotEmpty) _buildBodyMeasurementChart(),
      ],
    );
  }

  /// 신체 변화 카드 (단일 기록)
  Widget _buildBodyMeasurementCard(Map<String, dynamic> measurement) {
    final weight = measurement['weight_kg'] as double?;
    final fasting = measurement['blood_sugar_fasting'] as int?;
    final postprandial = measurement['blood_sugar_postprandial'] as int?;
    final memo = measurement['memo'] as String? ?? '';

    // 메모에서 시간대 추출 (아침/점심/저녁)
    String mealTime = '';
    if (memo.contains('아침')) {
      mealTime = '아침';
    } else if (memo.contains('점심')) {
      mealTime = '점심';
    } else if (memo.contains('저녁')) {
      mealTime = '저녁';
    }

    // 시간대가 없으면 메모 전체 표시, 있으면 시간대만 표시
    final displayTitle = mealTime.isNotEmpty ? mealTime : (memo.isNotEmpty ? memo : '신체 변화');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorPalette.primary100.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.primary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayTitle,
                style: const TextStyle(
                  color: ColorPalette.text100,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: ColorPalette.primary200),
                onPressed: () => _showBodyMeasurementDialog(existingMeasurement: measurement),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (weight != null) ...[
                Expanded(
                  child: _buildMeasurementItem('체중', '${weight.toStringAsFixed(1)}kg', Icons.monitor_weight),
                ),
                const SizedBox(width: 12),
              ],
              if (fasting != null) ...[
                Expanded(
                  child: _buildMeasurementItem('공복혈당', '${fasting}mg/dL', Icons.bloodtype),
                ),
                const SizedBox(width: 12),
              ],
              if (postprandial != null)
                Expanded(
                  child: _buildMeasurementItem('식후혈당', '${postprandial}mg/dL', Icons.bloodtype),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 측정 항목 위젯
  Widget _buildMeasurementItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ColorPalette.primary200),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: ColorPalette.text200,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: ColorPalette.text100,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 신체 변화 차트 (주간 추이)
  Widget _buildBodyMeasurementChart() {
    // 현재 주의 월요일 계산 (X축 기준점) - 시간을 00:00:00으로 정규화
    final selectedDate = _selectedDate;
    final weekday = selectedDate.weekday;
    final monday = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: weekday - 1));

    // 날짜만 비교하는 헬퍼 함수
    int getDaysFromMonday(DateTime date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final mondayOnly = DateTime(monday.year, monday.month, monday.day);
      return dateOnly.difference(mondayOnly).inDays;
    }

    // 체중 데이터 추출 (X축: 월요일부터의 일수, 0=월요일, 6=일요일)
    final weightData = _bodyMeasurements.where((m) => m['weight_kg'] != null).map((m) {
      final date = DateTime.parse(m['measurement_date'] as String);
      final weight = (m['weight_kg'] as num).toDouble();
      final daysFromMonday = getDaysFromMonday(date);
      return FlSpot(daysFromMonday.toDouble(), weight);
    }).toList();

    // 공복혈당 데이터 추출
    final fastingData = _bodyMeasurements.where((m) => m['blood_sugar_fasting'] != null).map((m) {
      final date = DateTime.parse(m['measurement_date'] as String);
      final sugar = (m['blood_sugar_fasting'] as int).toDouble();
      final daysFromMonday = getDaysFromMonday(date);
      return FlSpot(daysFromMonday.toDouble(), sugar);
    }).toList();

    // 식후혈당 데이터 추출
    final postprandialData = _bodyMeasurements.where((m) => m['blood_sugar_postprandial'] != null).map((m) {
      final date = DateTime.parse(m['measurement_date'] as String);
      final sugar = (m['blood_sugar_postprandial'] as int).toDouble();
      final daysFromMonday = getDaysFromMonday(date);
      return FlSpot(daysFromMonday.toDouble(), sugar);
    }).toList();

    // 데이터가 없으면 그래프 숨김
    if (weightData.isEmpty && fastingData.isEmpty && postprandialData.isEmpty) {
      return const SizedBox.shrink();
    }

    // 데이터가 1개만 있어도 그래프 표시 (단일 점으로 표시됨)

    // Y축 최소/최대값 계산
    double minY = 0;
    double maxY = 100;
    if (weightData.isNotEmpty) {
      final weights = weightData.map((spot) => spot.y).toList();
      final weightMin = weights.reduce((a, b) => a < b ? a : b);
      final weightMax = weights.reduce((a, b) => a > b ? a : b);
      minY = (weightMin - 5).clamp(0, double.infinity);
      maxY = (weightMax + 5);
    }
    if (fastingData.isNotEmpty || postprandialData.isNotEmpty) {
      final allSugars = <double>[];
      if (fastingData.isNotEmpty) {
        allSugars.addAll(fastingData.map((spot) => spot.y));
      }
      if (postprandialData.isNotEmpty) {
        allSugars.addAll(postprandialData.map((spot) => spot.y));
      }
      if (allSugars.isNotEmpty) {
        final sugarMin = allSugars.reduce((a, b) => a < b ? a : b);
        final sugarMax = allSugars.reduce((a, b) => a > b ? a : b);
        if (weightData.isEmpty) {
          minY = (sugarMin - 20).clamp(0, double.infinity);
          maxY = (sugarMax + 20);
        } else {
          // 체중과 혈당이 함께 있을 때는 별도 Y축이 필요하지만, 간단하게 표시
          minY = minY < (sugarMin - 20) ? minY : (sugarMin - 20).clamp(0, double.infinity);
          maxY = maxY > (sugarMax + 20) ? maxY : (sugarMax + 20);
        }
      }
    }

    // X축 날짜 레이블은 bottomTitles에서 직접 생성

    return Column(
      children: [
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorPalette.bg300),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6, // 월요일(0) ~ 일요일(6)
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: ColorPalette.bg300,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final dayIndex = value.toInt();
                      if (dayIndex >= 0 && dayIndex < 7) {
                        // 월요일 기준으로 정확한 날짜 계산 (시간 제거)
                        final mondayOnly = DateTime(monday.year, monday.month, monday.day);
                        final date = mondayOnly.add(Duration(days: dayIndex));
                        final dayOfWeek = ['월', '화', '수', '목', '금', '토', '일'][dayIndex];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.month}/${date.day}\n$dayOfWeek',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ColorPalette.text200,
                              fontSize: 9,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: ColorPalette.text200,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: ColorPalette.bg300),
              ),
              lineBarsData: [
                if (weightData.isNotEmpty)
                  LineChartBarData(
                    spots: weightData,
                    isCurved: true,
                    color: ColorPalette.primary200,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: ColorPalette.primary200,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                if (fastingData.isNotEmpty)
                  LineChartBarData(
                    spots: fastingData,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.orange,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                if (postprandialData.isNotEmpty)
                  LineChartBarData(
                    spots: postprandialData,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.red,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
              ],
            ),
          ),
        ),
        // 범례 추가
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (weightData.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ColorPalette.primary200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '체중',
                    style: TextStyle(
                      color: ColorPalette.text200,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            if (fastingData.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '공복혈당',
                    style: TextStyle(
                      color: ColorPalette.text200,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            if (postprandialData.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '식후혈당',
                    style: TextStyle(
                      color: ColorPalette.text200,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// 신체 변화 입력 다이얼로그
  Future<void> _showBodyMeasurementDialog({Map<String, dynamic>? existingMeasurement}) async {
    final weightController = TextEditingController();
    final fastingController = TextEditingController();
    final postprandialController = TextEditingController();
    String selectedMealTime = ''; // 아침/점심/저녁

    // 기존 데이터가 있으면 입력
    if (existingMeasurement != null) {
      if (existingMeasurement['weight_kg'] != null) {
        weightController.text = (existingMeasurement['weight_kg'] as double).toStringAsFixed(1);
      }
      if (existingMeasurement['blood_sugar_fasting'] != null) {
        fastingController.text = (existingMeasurement['blood_sugar_fasting'].toString());
      }
      if (existingMeasurement['blood_sugar_postprandial'] != null) {
        postprandialController.text = (existingMeasurement['blood_sugar_postprandial'].toString());
      }
      // 메모에서 시간대 추출
      final memo = existingMeasurement['memo'] as String? ?? '';
      if (memo.contains('아침')) {
        selectedMealTime = '아침';
      } else if (memo.contains('점심')) {
        selectedMealTime = '점심';
      } else if (memo.contains('저녁')) {
        selectedMealTime = '저녁';
      }
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('신체 변화 기록'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 식사 시간 선택
                    const Text(
                      '식사 시간',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorPalette.text100,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('아침'),
                            selected: selectedMealTime == '아침',
                            onSelected: (selected) {
                              setState(() {
                                selectedMealTime = selected ? '아침' : '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('점심'),
                            selected: selectedMealTime == '점심',
                            onSelected: (selected) {
                              setState(() {
                                selectedMealTime = selected ? '점심' : '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('저녁'),
                            selected: selectedMealTime == '저녁',
                            onSelected: (selected) {
                              setState(() {
                                selectedMealTime = selected ? '저녁' : '';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: weightController,
                      decoration: const InputDecoration(
                        labelText: '체중 (kg)',
                        hintText: '예: 65.5',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fastingController,
                      decoration: const InputDecoration(
                        labelText: '공복 혈당 (mg/dL)',
                        hintText: '예: 95',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: postprandialController,
                      decoration: const InputDecoration(
                        labelText: '식후 혈당 (mg/dL)',
                        hintText: '예: 140',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                if (existingMeasurement != null)
                  TextButton(
                    onPressed: () async {
                      // 삭제 확인
                      final deleteConfirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('삭제 확인'),
                          content: const Text('이 기록을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('삭제', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (deleteConfirm == true) {
                        Navigator.pop(context, {
                          'action': 'delete',
                          'measurement_id': existingMeasurement['measurement_id'],
                        });
                      }
                    },
                    child: const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'action': 'save',
                      'weight': weightController.text,
                      'fasting': fastingController.text,
                      'postprandial': postprandialController.text,
                      'mealTime': selectedMealTime,
                    });
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        // 삭제 처리
        await _deleteBodyMeasurement(result['measurement_id'] as int);
      } else if (result['action'] == 'save') {
        // 저장 처리
        final memo = result['mealTime'] as String? ?? '';
        await _saveBodyMeasurement(
          weightKg: result['weight'].toString().isNotEmpty ? double.tryParse(result['weight']) : null,
          bloodSugarFasting: result['fasting'].toString().isNotEmpty ? int.tryParse(result['fasting']) : null,
          bloodSugarPostprandial: result['postprandial'].toString().isNotEmpty
              ? int.tryParse(result['postprandial'])
              : null,
          memo: memo.isNotEmpty ? memo : null,
          measurementId: existingMeasurement?['measurement_id'] as int?,
        );
      }
    }

    weightController.dispose();
    fastingController.dispose();
    postprandialController.dispose();
  }

  /// 신체 변화 저장
  Future<void> _saveBodyMeasurement({
    double? weightKg,
    int? bloodSugarFasting,
    int? bloodSugarPostprandial,
    String? memo,
    int? measurementId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final bodyMeasurementApi = BodyMeasurementApiService.instance;
      await bodyMeasurementApi.saveBodyMeasurement(
        memberId: user.uid,
        measurementDate: dateStr,
        weightKg: weightKg,
        bloodSugarFasting: bloodSugarFasting,
        bloodSugarPostprandial: bloodSugarPostprandial,
        memo: memo,
        measurementId: measurementId, // 기존 기록 업데이트 시 사용
      );

      // 데이터 다시 로드
      await _loadBodyMeasurements();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신체 변화 기록이 저장되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('❌ [ReportScreen] 신체 변화 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  /// 신체 변화 삭제
  Future<void> _deleteBodyMeasurement(int measurementId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bodyMeasurementApi = BodyMeasurementApiService.instance;
      await bodyMeasurementApi.deleteBodyMeasurement(measurementId: measurementId);

      // 데이터 다시 로드
      await _loadBodyMeasurements();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신체 변화 기록이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('❌ [ReportScreen] 신체 변화 삭제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }
}

/// 커스텀 캘린더 다이얼로그 (기록된 날짜 표시)
class _CustomCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final String memberId;

  const _CustomCalendarDialog({
    required this.initialDate,
    required this.memberId,
  });

  @override
  State<_CustomCalendarDialog> createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<_CustomCalendarDialog> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  final Set<DateTime> _mealRecordedDates = <DateTime>{}; // 음식 기록이 있는 날짜
  final Set<DateTime> _bodyRecordedDates = <DateTime>{}; // 신체 변화 기록이 있는 날짜
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedDate = widget.initialDate;
    _loadRecordedDates(widget.initialDate.year, widget.initialDate.month);
  }

  /// 해당 월의 모든 날짜에 대해 기록 확인
  Future<void> _loadRecordedDates(int year, int month) async {
    setState(() {
      _isLoading = true;
      _mealRecordedDates.clear();
      _bodyRecordedDates.clear();
    });

    try {
      // 해당 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0); // 다음 달 0일 = 이번 달 마지막 날

      // 신체 변화 기록 조회 (월 단위)
      final bodyMeasurementApi = BodyMeasurementApiService.instance;
      final startDateStr = DateFormat('yyyy-MM-dd').format(firstDay);
      final endDateStr = DateFormat('yyyy-MM-dd').format(lastDay);

      try {
        final bodyResult = await bodyMeasurementApi.getBodyMeasurements(
          memberId: widget.memberId,
          startDate: startDateStr,
          endDate: endDateStr,
        );

        if (bodyResult['success'] == true) {
          final measurements = bodyResult['measurements'] as List<dynamic>? ?? [];
          for (final measurement in measurements) {
            final dateStr = measurement['measurement_date'] as String?;
            if (dateStr != null) {
              try {
                final date = DateTime.parse(dateStr);
                _bodyRecordedDates.add(DateTime(date.year, date.month, date.day));
              } catch (e) {
                debugPrint('⚠️ [CustomCalendarDialog] 날짜 파싱 실패: $dateStr');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [CustomCalendarDialog] 신체 변화 기록 조회 실패: $e');
      }

      // 음식 기록 조회 (각 날짜별로 확인)
      final mealApiService = MealApiService.instance;
      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(year, month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        try {
          final result = await mealApiService.getMeals(
            memberId: widget.memberId,
            date: dateStr,
          );
          if (result['success'] == true) {
            final meals = result['meals'] as List;
            if (meals.isNotEmpty) {
              _mealRecordedDates.add(date);
            }
          }
        } catch (e) {
          debugPrint('⚠️ [CustomCalendarDialog] 음식 기록 조회 실패 ($dateStr): $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [CustomCalendarDialog] 기록 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 날짜에 기록이 있는지 확인하고 색상 정보 반환
  /// null: 기록 없음, List<Color>: 기록이 있는 색상 목록
  List<Color>? _getRecordColors(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final hasMeal = _mealRecordedDates.any((recorded) {
      final recordedOnly = DateTime(recorded.year, recorded.month, recorded.day);
      return dateOnly.isAtSameMomentAs(recordedOnly);
    });
    final hasBody = _bodyRecordedDates.any((recorded) {
      final recordedOnly = DateTime(recorded.year, recorded.month, recorded.day);
      return dateOnly.isAtSameMomentAs(recordedOnly);
    });

    final colors = <Color>[];
    if (hasMeal) {
      colors.add(Colors.blue); // 음식 분석만 - 파란색
    }
    if (hasBody) {
      colors.add(Colors.red); // 혈당만 - 빨간색
    }

    return colors.isNotEmpty ? colors : null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '날짜 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColorPalette.text100,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: ColorPalette.text200),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 캘린더
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDate,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDate = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDate = focusedDay;
                });
                // 월이 변경되면 해당 월의 기록 다시 로드
                if (focusedDay.year != _focusedDate.year || focusedDay.month != _focusedDate.month) {
                  _loadRecordedDates(focusedDay.year, focusedDay.month);
                }
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: ColorPalette.primary200,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: ColorPalette.primary200.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              // 선택된 날짜의 색상을 기록에 맞게 표시
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, date, focused) {
                  // 선택된 날짜의 배경색을 기록에 맞게 변경
                  final colors = _getRecordColors(date);
                  if (colors != null && colors.isNotEmpty) {
                    // 기록이 있으면 해당 색상으로 표시
                    Color bgColor;
                    if (colors.length == 2) {
                      // 둘 다 있으면 첫 번째 색상(파란색) 사용
                      bgColor = colors[0];
                    } else {
                      bgColor = colors[0];
                    }
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  // 기록이 없으면 기본 선택 색상 사용
                  return null;
                },
                markerBuilder: (context, date, events) {
                  // 모든 날짜에 도형 표시 (선택된 날짜 포함)
                  final colors = _getRecordColors(date);
                  if (colors == null || colors.isEmpty) {
                    return null;
                  }

                  // 하나만 있으면 하나의 원, 둘 다 있으면 두 개의 원 표시
                  if (colors.length == 1) {
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors[0],
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  } else {
                    // 둘 다 있으면 두 개의 원을 나란히 표시
                    return Positioned(
                      bottom: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors[0],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors[1],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: const Icon(Icons.chevron_left, color: ColorPalette.text100),
                rightChevronIcon: const Icon(Icons.chevron_right, color: ColorPalette.text100),
                titleTextStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ColorPalette.text100,
                ),
              ),
              // 기록된 날짜에 표시
              eventLoader: (day) {
                final colors = _getRecordColors(day);
                if (colors != null && colors.isNotEmpty) {
                  return colors; // 색상 목록 반환
                }
                return [];
              },
            ),
            const SizedBox(height: 16),
            // 범례
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '파란색: 음식 분석',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorPalette.text200,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '빨간색: 혈당 검사',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorPalette.text200,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: ColorPalette.text200),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  style: TextButton.styleFrom(
                    backgroundColor: ColorPalette.primary200,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
