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
      final imageBytes = await imageFile.readAsBytes();
      imageBase64 = base64Encode(imageBytes);
    }

    final bodyData = {
      "user_message": userMessage,
      "nickname": nickname ?? "사용자",
      "week": week ?? 12,
      "conditions": conditions ?? "없음",
      if (imageBase64 != null) "image_base64": imageBase64,
    };

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

    if (resp.statusCode != 200) {
      throw Exception('status=${resp.statusCode}, body=${resp.body}');
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return ChatResponse(message: json['message'] as String);
  } catch (e) {
    print("채팅 API 에러: $e");
    rethrow;
  }
}
