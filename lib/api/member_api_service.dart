import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// 회원 + 건강정보 API 호출 전담 서비스
class MemberApiService {
  MemberApiService._();
  static final MemberApiService instance = MemberApiService._();

  /// 1) 회원 등록 API
  /// POST {apiBaseUrl}/api/member/register/
  /// body: { "uid": "firebase-uid", "email": "user@example.com", "nickname": "닉네임" }
  Future<Map<String, dynamic>> registerMember(
    String uid, {
    String? email,
    String? nickname,
  }) async {
    final url = Uri.parse('$apiBaseUrl/api/member/register/');

    final bodyMap = {'uid': uid};
    if (email != null) {
      bodyMap['email'] = email;
    }
    if (nickname != null) {
      bodyMap['nickname'] = nickname;
    }

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw Exception('registerMember 실패: ${res.statusCode} $body');
    }

    return body;
  }

  /// 2) 건강정보 저장 API
  /// POST {apiBaseUrl}/api/health/
  Future<void> saveHealthInfo({
    required String memberId,
    required int birthYear,
    required double heightCm,
    required double weightKg,
    required DateTime dueDate,
    required int pregWeek,
    required bool hasGestationalDiabetes,
    required List<String> allergies,
  }) async {
    final url = Uri.parse('$apiBaseUrl/api/health/');

    // dueDate를 YYYY-MM-DD 형식으로 변환 (Django parse_date 호환)
    final dueDateStr =
        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'memberId': memberId,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'dueDate': dueDateStr,
        'pregWeek': pregWeek,
        'hasGestationalDiabetes': hasGestationalDiabetes,
        'allergies': allergies,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('saveHealthInfo 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 3) 건강정보 조회 API
  /// GET {apiBaseUrl}/api/health/{memberId}/
  Future<Map<String, dynamic>> getHealthInfo(String memberId) async {
    final url = Uri.parse('$apiBaseUrl/api/health/$memberId/');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception(
        'getHealthInfo 실패: ${res.statusCode} ${res.body}',
      );
    }

    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 4) 임신 모드 업데이트 API
  /// POST {apiBaseUrl}/api/member/pregnant-mode/
  /// body: { "uid": "firebase-uid", "is_pregnant_mode": true }
  Future<Map<String, dynamic>> updatePregnantMode(String uid, bool isPregnantMode) async {
    final url = Uri.parse('$apiBaseUrl/api/member/pregnant-mode/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uid,
        'is_pregnant_mode': isPregnantMode,
      }),
    );

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw Exception('updatePregnantMode 실패: ${res.statusCode} $body');
    }

    return body;
  }

  /// 5) 임신 분기별 영양소 권장량 조회 API
  /// GET {apiBaseUrl}/api/nutrition-target/{trimester}/
  ///
  /// [trimester] 임신 분기 (1, 2, 3)
  /// Returns MemberNutritionTarget 데이터
  Future<Map<String, dynamic>> getNutritionTarget(int trimester) async {
    final url = Uri.parse('$apiBaseUrl/api/nutrition-target/$trimester/');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception(
        'getNutritionTarget 실패: ${res.statusCode} ${res.body}',
      );
    }

    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 6) 일별 영양소 데이터 조회 API
  /// GET {apiBaseUrl}/api/nutrients/daily?date=YYYY-MM-DD
  ///
  /// [date] 조회할 날짜
  /// Returns DailyNutrientStatus를 생성할 수 있는 JSON 데이터
  ///
  /// Response 예시:
  /// {
  ///   "recommended": {
  ///     "energy": 2200,
  ///     "carb": 260,
  ///     "protein": 70,
  ///     "fat": 70,
  ///     "sodium": 2000,
  ///     "iron": 27,
  ///     "folate": 600,
  ///     "calcium": 1000,
  ///     "vitaminD": 15,
  ///     "omega3": 300,
  ///     "vitaminB": 450
  ///   },
  ///   "consumed": {
  ///     "energy": 1500,
  ///     "carb": 180,
  ///     "protein": 50,
  ///     "fat": 45,
  ///     "sodium": 1800,
  ///     "iron": 20,
  ///     "folate": 400,
  ///     "calcium": 600,
  ///     "vitaminD": 10,
  ///     "omega3": 200,
  ///     "choline": 300
  ///   }
  /// }
  ///
  /// TODO: [SERVER][DB] HTTP 클라이언트로 일별 영양 데이터 조회 구현
  Future<Map<String, dynamic>?> fetchDailyNutrients({required DateTime date}) async {
    // TODO: [SERVER][DB] 실제 API 호출 구현
    // final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    // final url = Uri.parse('$apiBaseUrl/api/nutrients/daily?date=$dateStr');
    //
    // final res = await http.get(url);
    //
    // if (res.statusCode != 200) {
    //   throw Exception('fetchDailyNutrients 실패: ${res.statusCode} ${res.body}');
    // }
    //
    // return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return null;
  }
}
