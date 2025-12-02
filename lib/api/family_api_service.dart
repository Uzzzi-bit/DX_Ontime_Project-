import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// 가족 구성원 API 호출 전담 서비스
class FamilyApiService {
  FamilyApiService._();
  static final FamilyApiService instance = FamilyApiService._();

  /// 가족 구성원 업데이트 (전체 동기화)
  /// POST {apiBaseUrl}/api/family/update/
  /// body: {
  ///   "member_id": "firebase-uid",
  ///   "relation_types": ["배우자", "부모님", ...]  // 선택된 relation_type 목록
  /// }
  Future<Map<String, dynamic>> updateFamilyMembers(
    String memberId,
    List<String> relationTypes,
  ) async {
    final url = Uri.parse('$apiBaseUrl/api/family/update/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'member_id': memberId,
        'relation_types': relationTypes,
      }),
    );

    // 응답이 HTML인지 확인 (에러 페이지일 수 있음)
    final responseBody = utf8.decode(res.bodyBytes);

    // 403 Forbidden 에러 처리
    if (res.statusCode == 403) {
      throw Exception(
        '403 Forbidden: 서버 접근이 거부되었습니다.\n'
        'Django 서버가 실행 중인지, URL이 올바른지 확인하세요.\n'
        '요청 URL: $url\n'
        '응답: ${responseBody.substring(0, 300)}...',
      );
    }

    if (responseBody.trim().startsWith('<!DOCTYPE') || responseBody.trim().startsWith('<html')) {
      throw Exception(
        '서버가 HTML을 반환했습니다. Django 서버가 실행 중인지 확인하세요.\n'
        '상태 코드: ${res.statusCode}\n'
        '응답: ${responseBody.substring(0, 200)}...',
      );
    }

    try {
      final body = jsonDecode(responseBody) as Map<String, dynamic>;

      if (res.statusCode != 200) {
        throw Exception('updateFamilyMembers 실패: ${res.statusCode} $body');
      }

      return body;
    } catch (e) {
      if (e is FormatException) {
        throw Exception('JSON 파싱 실패. 서버 응답: ${responseBody.substring(0, 300)}...');
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
