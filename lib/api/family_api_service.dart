import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// 가족 구성원 API 호출 전담 서비스
class FamilyApiService {
  FamilyApiService._();
  static final FamilyApiService instance = FamilyApiService._();

  /// 가족 구성원 추가
  /// POST {apiBaseUrl}/api/family/add/
  /// body: {
  ///   "member_id": "firebase-uid",
  ///   "guardians": [
  ///     {"guardian_member_id": "guardian-uid", "relation_type": "배우자"},
  ///     ...
  ///   ]
  /// }
  Future<Map<String, dynamic>> addFamilyMembers(
    String memberId,
    List<Map<String, String>> guardians,
  ) async {
    final url = Uri.parse('$apiBaseUrl/api/family/add/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'member_id': memberId,
        'guardians': guardians,
      }),
    );

    // 응답이 HTML인지 확인 (에러 페이지일 수 있음)
    final responseBody = utf8.decode(res.bodyBytes);
    if (responseBody.trim().startsWith('<!DOCTYPE') || 
        responseBody.trim().startsWith('<html')) {
      throw Exception(
        '서버가 HTML을 반환했습니다. Django 서버가 실행 중인지 확인하세요.\n'
        '응답: ${responseBody.substring(0, 200)}...'
      );
    }

    try {
      final body = jsonDecode(responseBody) as Map<String, dynamic>;
      
      if (res.statusCode != 200) {
        throw Exception('addFamilyMembers 실패: ${res.statusCode} $body');
      }

      return body;
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
          'JSON 파싱 실패. 서버 응답: ${responseBody.substring(0, 300)}...'
        );
      }
      rethrow;
    }
  }

  /// 가족 구성원 조회
  /// GET {apiBaseUrl}/api/family/{memberId}/
  Future<Map<String, dynamic>> getFamilyMembers(String memberId) async {
    final url = Uri.parse('$apiBaseUrl/api/family/$memberId/');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception(
        'getFamilyMembers 실패: ${res.statusCode} ${res.body}',
      );
    }

    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}

