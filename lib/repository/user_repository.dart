import '../model/user_model.dart';
import '../model/daily_nutrient_status.dart';

class UserRepository {
  // TODO: CONNECT TO DJANGO BACKEND
  // 서버 연동 시 이 함수를 실제 API 호출로 대체
  static Future<UserModel> getDummyUser() async {
    // Mock 데이터 반환
    await Future.delayed(const Duration(milliseconds: 300)); // 네트워크 지연 시뮬레이션

    return UserModel(
      nickname: '김레제',
      pregnancyWeek: 20,
      statusMessage: '건강한 임신 생활을 응원합니다!',
      dueDate: DateTime(2026, 7, 1),
    );
  }

  // TODO: [SERVER][DB] 일별 영양 리포트 조회 API
  ///
  /// 특정 날짜의 일별 영양소 섭취 현황을 조회합니다.
  ///
  /// [date] 조회할 날짜
  /// Returns 해당 날짜의 DailyNutrientStatus, 데이터가 없으면 null
  ///
  /// API 엔드포인트: GET /api/nutrients/daily?date=YYYY-MM-DD
  /// Response 예시:
  /// {
  ///   "recommended": { "energy": 2200, "carb": 260, "protein": 70, ... },
  ///   "consumed": { "energy": 1500, "carb": 180, "protein": 50, ... }
  /// }
  static Future<DailyNutrientStatus?> fetchDailyNutrients({
    required DateTime date,
  }) async {
    // TODO: [SERVER][DB] 실제 API 호출로 대체
    // 예시:
    // final response = await MemberApiService.instance.fetchDailyNutrients(date: date);
    // if (response == null) return null;
    // return DailyNutrientStatus.fromJson(response);
    return null;
  }
}
