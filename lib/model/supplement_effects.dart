import 'nutrient_type.dart';

/// 영양제별 영양소 증가 효과를 정의하는 클래스
///
/// 각 영양제 id에 대해 해당 영양소별 증가 퍼센트를 정의합니다.
/// 모든 사용자에게 공통으로 적용되는 가정값입니다.
class SupplementEffects {
  /// 각 영양제 id -> 해당 영양소별 증가 퍼센트 맵
  ///
  /// 값은 퍼센트 포인트를 의미합니다.
  /// 예: iron 70.0에서 철분제 체크 → 70.0 + 20.0 = 90.0
  static final Map<String, Map<NutrientType, double>> effects = {
    'iron-pill': {
      NutrientType.iron: 20.0,
    },
    'calcium': {
      NutrientType.calcium: 20.0,
    },
    'vitamin-complex': {
      NutrientType.folate: 20.0,
      NutrientType.iron: 10.0,
      NutrientType.vitaminD: 10.0,
    },
    'omega3': {
      NutrientType.omega3: 20.0,
    },
    'vitaminD': {
      NutrientType.vitaminD: 20.0,
    },
    'vitaminB': {
      NutrientType.vitaminB: 20.0,
    },
  };

  /// 특정 영양제 id의 효과를 반환합니다.
  ///
  /// 영양제가 존재하지 않으면 null을 반환합니다.
  static Map<NutrientType, double>? getEffect(String supplementId) {
    return effects[supplementId];
  }
}
