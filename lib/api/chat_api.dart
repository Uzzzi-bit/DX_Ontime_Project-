// lib/api/chat_api.dart

import 'dart:convert';
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
      final imageBytes = await imageFile.readAsBytes();
      print('🖼️ [ChatAPI] 이미지 파일 크기: ${imageBytes.length} bytes');
      imageBase64 = base64Encode(imageBytes);
      print('🖼️ [ChatAPI] Base64 인코딩 완료: ${imageBase64.length} characters');
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
    
    print('📤 [ChatAPI] 요청 데이터: user_message=$userMessage, has_image=${imageBase64 != null}');

    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${GeminiConfig.apiKey}',
          },
          body: jsonEncode(bodyData),
        )
        .timeout(const Duration(seconds: 30));

    print('📥 [ChatAPI] 응답 상태 코드: ${resp.statusCode}');
    
    if (resp.statusCode != 200) {
      print('❌ [ChatAPI] 에러 응답: ${resp.body}');
      throw Exception('status=${resp.statusCode}, body=${resp.body}');
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final message = json['message'] as String;
    print('✅ [ChatAPI] 응답 메시지 길이: ${message.length} characters');
    return ChatResponse(message: message);
  } catch (e, stackTrace) {
    print("❌ [ChatAPI] 채팅 API 에러: $e");
    print("❌ [ChatAPI] 스택 트레이스: $stackTrace");
    rethrow;
  }
}
