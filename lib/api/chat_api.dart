// lib/api/chat_api.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/gemini_config.dart';

class ChatResponse {
  final String message;

  ChatResponse({required this.message});
}

Future<ChatResponse> fetchChatResponse({
  required String userMessage,
  String? nickname,
  int? week,
  String? conditions,
  XFile? imageFile,
}) async {
  final uri = Uri.parse('$kAiBaseUrl/api/chat');

  try {
    // 이미지를 base64로 인코딩
    String? imageBase64;
    if (imageFile != null) {
      print('🖼️ [ChatAPI] 이미지 파일 읽기 시작: ${imageFile.path}');
      try {
        final file = File(imageFile.path);
        final fileExists = await file.exists();
        if (!fileExists) {
          throw Exception('이미지 파일을 찾을 수 없습니다: ${imageFile.path}');
        }
        final imageBytes = await file.readAsBytes();
        print('🖼️ [ChatAPI] 이미지 파일 크기: ${imageBytes.length} bytes');
        if (imageBytes.isEmpty) {
          throw Exception('이미지 파일이 비어있습니다: ${imageFile.path}');
        }
        imageBase64 = base64Encode(imageBytes);
        print('🖼️ [ChatAPI] Base64 인코딩 완료: ${imageBase64.length} characters');
      } catch (e) {
        print('❌ [ChatAPI] 이미지 처리 실패: $e');
        throw Exception('이미지 처리 실패: $e');
      }
    } else {
      print('📝 [ChatAPI] 이미지 없음 - 텍스트만 전송');
    }

    final bodyData = {
      "user_message": userMessage,
      "nickname": nickname ?? "사용자",
      "week": week ?? 12,
      "conditions": conditions ?? "없음",
      if (imageBase64 != null) "image_base64": imageBase64,
    };

    print('📤 [ChatAPI] 요청 URL: $uri');
    print(
      '📤 [ChatAPI] 요청 데이터: user_message=$userMessage, has_image=${imageBase64 != null}, nickname=$nickname, week=$week',
    );

    http.Response resp;
    try {
      print('🔄 [ChatAPI] 서버 연결 시도: $uri');
      resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${GeminiConfig.apiKey}',
            },
            body: jsonEncode(bodyData),
          )
          .timeout(
            const Duration(seconds: 120), // 타임아웃 120초로 증가 (이미지 처리 시간 고려)
            onTimeout: () {
              print("❌ [ChatAPI] 요청 시간 초과 (120초)");
              throw TimeoutException('AI 서버 응답 시간이 초과되었습니다. 서버가 정상적으로 작동하는지 확인해주세요.');
            },
          );
    } on TimeoutException catch (e) {
      print("❌ [ChatAPI] 요청 시간 초과: $e");
      throw Exception('AI 서버 응답 시간이 초과되었습니다. 서버가 정상적으로 작동하는지 확인해주세요.\n(URL: $uri)');
    } on SocketException catch (e) {
      print("❌ [ChatAPI] 네트워크 연결 오류: $e");
      throw Exception('AI 서버에 연결할 수 없습니다. 네트워크 연결과 서버 실행 상태를 확인해주세요.\n(URL: $uri)');
    } on HttpException catch (e) {
      print("❌ [ChatAPI] HTTP 오류: $e");
      throw Exception('AI 서버 HTTP 오류: $e\n(URL: $uri)');
    } catch (e) {
      print("❌ [ChatAPI] 예상치 못한 오류: $e");
      if (e.toString().contains('Timeout') || e.toString().contains('시간 초과')) {
        throw Exception('AI 서버 응답 시간이 초과되었습니다. 서버가 정상적으로 작동하는지 확인해주세요.\n(URL: $uri)');
      }
      throw Exception('AI 서버 연결 오류: $e\n(URL: $uri)');
    }

    print('📥 [ChatAPI] 응답 상태 코드: ${resp.statusCode}');

    if (resp.statusCode != 200) {
      final errorBody = resp.body;
      print('❌ [ChatAPI] 에러 응답: $errorBody');

      // 연결 오류인 경우 더 명확한 메시지
      if (resp.statusCode == 0 || errorBody.isEmpty) {
        throw Exception('AI 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.\n(URL: $uri)');
      }
      throw Exception('AI 서버 오류 (${resp.statusCode}): $errorBody');
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final message = json['message'] as String? ?? json['response'] as String? ?? '응답을 받을 수 없습니다.';
    print('✅ [ChatAPI] 응답 메시지 길이: ${message.length} characters');
    return ChatResponse(message: message);
  } catch (e, stackTrace) {
    // 이미 처리된 예외는 다시 throw하지 않음
    if (e.toString().contains('AI 서버') || e.toString().contains('연결') || e.toString().contains('시간 초과')) {
      rethrow;
    }
    print("❌ [ChatAPI] 채팅 API 에러: $e");
    print("❌ [ChatAPI] 스택 트레이스: $stackTrace");
    rethrow;
  }
}
