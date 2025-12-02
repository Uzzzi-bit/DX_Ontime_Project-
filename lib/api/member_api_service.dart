import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// 회원 + 건강정보 API 호출 전담 서비스
class MemberApiService {
  MemberApiService._();
  static final MemberApiService instance = MemberApiService._();

  /// 1) 회원 등록 API
  /// POST {apiBaseUrl}/api/member/register/
  /// body: { "uid": "firebase-uid", "email": "user@example.com" }
  Future<Map<String, dynamic>> registerMember(String uid, {String? email}) async {
    final url = Uri.parse('$apiBaseUrl/api/member/register/');

    final bodyMap = {'uid': uid};
    if (email != null) {
      bodyMap['email'] = email;
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
}
