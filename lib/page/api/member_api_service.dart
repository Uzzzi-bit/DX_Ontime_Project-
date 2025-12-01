// lib/api/member_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// 회원 관련 API 호출 전담 서비스
class MemberApiService {
  // 싱글톤 패턴 (어디서나 MemberApiService.instance 로 사용)
  MemberApiService._();
  static final MemberApiService instance = MemberApiService._();

  /// 1) 회원 등록 API
  /// POST {apiBaseUrl}/api/member/register/
  /// body: { "uid": "firebase-uid" }
  Future<Map<String, dynamic>> registerMember(String uid) async {
    final url = Uri.parse('$apiBaseUrl/api/member/register/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'registerMember 실패: ${res.statusCode} ${res.body}',
      );
    }

    // {"ok": true, "created": true/false, "uid": "...", ...}
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 2) 건강 정보 저장 API
  /// POST {apiBaseUrl}/api/health/
  ///
  /// dueDateIso 는 "2025-10-01" 또는 "2025-10-01T00:00:00.000Z" 형식
  Future<void> saveHealthInfo({
    required String memberId,
    required int birthYear,
    required double heightCm,
    required double weightKg,
    required String dueDateIso,
    required bool hasGestationalDiabetes,
    required List<String> allergies,
    int? pregWeek,
  }) async {
    final url = Uri.parse('$apiBaseUrl/api/health/');

    final body = <String, dynamic>{
      'memberId': memberId,
      'birthYear': birthYear,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'dueDate': dueDateIso,
      'hasGestationalDiabetes': hasGestationalDiabetes,
      'allergies': allergies,
      if (pregWeek != null) 'pregWeek': pregWeek,
    };

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'saveHealthInfo 실패: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// 3) 건강 정보 조회 API
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
