// lib/model/daily_nutrient_status.dart

import 'dart:math';
import 'nutrient_type.dart';

/// 하루 권장량 세트
class RecommendedNutrientConfig {
  final Map<NutrientType, double> perDay; // 단위는 nutrient_type.dart 주석 기준

  const RecommendedNutrientConfig({required this.perDay});
}

/// 예시: 임신 중기 기본 권장량 (나중에 수정 가능)
const defaultMidPregnancyConfig = RecommendedNutrientConfig(
  perDay: {
    NutrientType.energy: 2200, // kcal
    NutrientType.carb: 260, // g
    NutrientType.protein: 70, // g
    NutrientType.fat: 70, // g (대략)
    NutrientType.sodium: 2000, // mg

    NutrientType.iron: 27, // mg
    NutrientType.folate: 600, // ug
    NutrientType.calcium: 1000, // mg
    NutrientType.vitaminD: 15, // ug (600 IU)
    NutrientType.omega3: 300, // mg
    NutrientType.vitaminB: 450, // mg (원하면 조정)
  },
);

/// 오늘 섭취 현황 + 권장량을 한 번에 들고 있는 모델
class DailyNutrientStatus {
  /// 오늘까지 누적 섭취량
  final Map<NutrientType, double> consumed;

  /// 하루 권장량
  final Map<NutrientType, double> recommended;

  const DailyNutrientStatus({
    required this.consumed,
    required this.recommended,
  });

  /// 해당 영양소의 섭취 비율 (0.0 ~ 2.0 = 0% ~ 200%)
  double getProgress(NutrientType type) {
    final rec = recommended[type] ?? 0;
    if (rec == 0) return 0;
    final value = consumed[type] ?? 0;
    return (value / rec).clamp(0, 2); // 0~200% 제한
  }

  /// 섭취량을 추가한 새로운 상태 반환
  DailyNutrientStatus addIntake(Map<NutrientType, double> delta) {
    final newConsumed = Map<NutrientType, double>.from(consumed);
    delta.forEach((key, value) {
      newConsumed[key] = (newConsumed[key] ?? 0) + value;
    });
    return DailyNutrientStatus(
      consumed: newConsumed,
      recommended: recommended,
    );
  }

  /// JSON으로부터 DailyNutrientStatus 생성
  ///
  /// 서버 응답으로부터 쉽게 만들 수 있도록 하는 팩토리 생성자입니다.
  /// 예시 JSON:
  /// {
  ///   "recommended": { "energy": 2200, "carb": 260, ... },
  ///   "consumed": { "energy": 1500, "carb": 180, ... }
  /// }
  factory DailyNutrientStatus.fromJson(Map<String, dynamic> json) {
    Map<NutrientType, double> _toMap(Map<String, dynamic>? data) {
      final result = <NutrientType, double>{};
      if (data == null) return result;
      data.forEach((key, value) {
        final type = _nutrientTypeFromString(key);
        if (type != null) {
          result[type] = (value as num).toDouble();
        }
      });
      return result;
    }

    return DailyNutrientStatus(
      consumed: _toMap(json['consumed']),
      recommended: _toMap(json['recommended']),
    );
  }
}

/// 문자열을 NutrientType으로 변환하는 헬퍼 함수
NutrientType? _nutrientTypeFromString(String key) {
  switch (key) {
    case 'energy':
      return NutrientType.energy;
    case 'carb':
      return NutrientType.carb;
    case 'protein':
      return NutrientType.protein;
    case 'fat':
      return NutrientType.fat;
    case 'sodium':
      return NutrientType.sodium;
    case 'iron':
      return NutrientType.iron;
    case 'vitaminD':
      return NutrientType.vitaminD;
    case 'folate':
      return NutrientType.folate;
    case 'omega3':
      return NutrientType.omega3;
    case 'calcium':
      return NutrientType.calcium;
    case 'vitaminB':
      return NutrientType.vitaminB;
    default:
      return null;
  }
}

/// 테스트용: “대충 60~90% 채워진 오늘 섭취량” 더미 생성
DailyNutrientStatus createDummyTodayStatus() {
  final rec = defaultMidPregnancyConfig.perDay;

  final consumed = <NutrientType, double>{};
  for (final entry in rec.entries) {
    final ratio = 0.6 + (Random().nextDouble() * 0.3); // 60~90%
    consumed[entry.key] = entry.value * ratio;
  }

  return DailyNutrientStatus(
    consumed: consumed,
    recommended: rec,
  );
}
