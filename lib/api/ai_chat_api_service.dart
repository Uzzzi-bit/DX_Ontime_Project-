// lib/api/ai_chat_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// AI 채팅 세션 및 메시지 관리 API 서비스
class AiChatApiService {
  static final AiChatApiService instance = AiChatApiService._();
  AiChatApiService._();

  /// 세션 생성
  /// POST /api/ai-chat/sessions/
  Future<Map<String, dynamic>> createSession(String memberId) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/sessions/');

    print('🔄 [AiChatApiService] 세션 생성 API 호출: $url');
    print('🔄 [AiChatApiService] memberId: $memberId');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'member_id': memberId}),
          )
          .timeout(const Duration(seconds: 10));

      print('🔄 [AiChatApiService] 세션 생성 응답 상태: ${response.statusCode}');
      print('🔄 [AiChatApiService] 세션 생성 응답 body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ [AiChatApiService] 세션 생성 성공: session_id=${data['session_id']}');
        return data;
      } else {
        print('❌ [AiChatApiService] 세션 생성 실패: ${response.statusCode}, body: ${response.body}');
        throw Exception('세션 생성 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ [AiChatApiService] 세션 생성 오류: $e');
      throw Exception('세션 생성 오류: $e');
    }
  }

  /// 세션 조회
  /// GET /api/ai-chat/sessions/{session_id}/
  Future<Map<String, dynamic>> getSession(int sessionId) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/sessions/$sessionId/');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('세션을 찾을 수 없습니다');
      } else {
        throw Exception('세션 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('세션 조회 오류: $e');
    }
  }

  /// 사용자의 세션 목록 조회
  /// GET /api/ai-chat/sessions/{member_id}/list/
  Future<List<Map<String, dynamic>>> listSessions(String memberId) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/sessions/$memberId/list/');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return (data['sessions'] as List).cast<Map<String, dynamic>>();
      } else {
        throw Exception('세션 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('세션 목록 조회 오류: $e');
    }
  }

  /// 세션 종료
  /// POST /api/ai-chat/sessions/{session_id}/end/
  Future<Map<String, dynamic>> endSession(int sessionId) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/sessions/$sessionId/end/');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('세션을 찾을 수 없습니다');
      } else {
        throw Exception('세션 종료 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('세션 종료 오류: $e');
    }
  }

  /// 세션 재활성화
  /// POST /api/ai-chat/sessions/{session_id}/reactivate/
  Future<Map<String, dynamic>> reactivateSession(int sessionId) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/sessions/$sessionId/reactivate/');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('세션을 찾을 수 없습니다');
      } else {
        throw Exception('세션 재활성화 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('세션 재활성화 오류: $e');
    }
  }

  /// 메시지 저장
  /// POST /api/ai-chat/messages/
  Future<Map<String, dynamic>> saveMessage({
    required int sessionId,
    required String memberId,
    required String type, // 'user' or 'ai'
    required String content,
    int? imagePk,
  }) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/messages/');

    final body = {
      'session_id': sessionId,
      'member_id': memberId,
      'type': type,
      'content': content,
    };

    if (imagePk != null) {
      body['image_pk'] = imagePk;
    }

    print('🔄 [AiChatApiService] 메시지 저장 API 호출: $url');
    print('🔄 [AiChatApiService] 요청 body: $body');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      print('🔄 [AiChatApiService] 응답 상태: ${response.statusCode}');
      print('🔄 [AiChatApiService] 응답 body: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        print('❌ [AiChatApiService] 메시지 저장 실패: ${response.statusCode}, body: ${response.body}');
        throw Exception('메시지 저장 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ [AiChatApiService] 메시지 저장 오류: $e');
      throw Exception('메시지 저장 오류: $e');
    }
  }

  /// 세션의 메시지 목록 조회
  /// GET /api/ai-chat/sessions/{session_id}/messages/
  Future<List<Map<String, dynamic>>> getMessages(int sessionId) async {
    final url = Uri.parse('$apiBaseUrl/api/ai-chat/sessions/$sessionId/messages/');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return (data['messages'] as List).cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        throw Exception('세션을 찾을 수 없습니다');
      } else {
        throw Exception('메시지 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('메시지 조회 오류: $e');
    }
  }
}
