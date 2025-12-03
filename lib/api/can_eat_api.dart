// lib/api/can_eat_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/gemini_config.dart';

class CanEatResponse {
  final String status;
  final String headline;
  final String reason;
  final String targetType;
  final String itemName;

  CanEatResponse({
    required this.status,
    required this.headline,
    required this.reason,
    required this.targetType,
    required this.itemName,
  });
}

Future<CanEatResponse> fetchCanEat({
  String? query,
  XFile? imageFile, // 서버가 지원 안 해서 지금은 안 쓰임
  String? nickname,
  int? week,
  double? bmi,
  String? conditions,
}) async {
  // 1. 주소 확인 (Swagger에 나온 주소 그대로)
  final uri = Uri.parse('$kAiBaseUrl/api/can-eat');

  try {
    // 2. [중요] '택배(Multipart)' 대신 '편지(JSON)'로 데이터 준비
    // Swagger에 적힌 이름(Key)과 똑같이 맞춰야 합니다.
    final Map<String, dynamic> bodyData = {
      "user_text_or_image_desc": query ?? "음식 정보 요청", // 여기가 핵심!
      "nickname": nickname ?? "사용자",
      "week": week ?? 12,
      "conditions": conditions ?? "없음",
    };

    // 3. 전송 (http.post 사용)
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json', // "나 편지(JSON) 보낸다!"고 알려줌
        'Authorization': 'Bearer ${GeminiConfig.apiKey}',
      },
      body: jsonEncode(bodyData), // 데이터를 JSON 문자열로 포장
    );

    if (resp.statusCode != 200) {
      throw Exception('status=${resp.statusCode}, body=${resp.body}');
    }

    // 4. 응답 처리
    // (한글 깨짐 방지용 utf8.decode 추가)
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

    return CanEatResponse(
      status: json['status']?.toString() ?? 'ok',
      headline: json['headline']?.toString() ?? '분석 결과',
      reason: json['reason']?.toString() ?? '결과를 받아왔습니다.',
      targetType: json['target_type']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
    );
  } catch (e) {
    print("API 에러: $e");
    return CanEatResponse(
      status: 'error',
      headline: '분석에 실패했어요.',
      reason: '서버와 연결할 수 없거나 형식이 맞지 않습니다.',
      targetType: '',
      itemName: '',
    );
  }
}

// 헬퍼 함수들
Future<CanEatResponse> fetchCanEatFromText(String query) {
  return fetchCanEat(query: query);
}

Future<CanEatResponse> fetchCanEatFromImage(XFile imageFile, {String? query}) {
  // 이미지는 못 보내지만 질문이라도 보냄
  return fetchCanEat(query: query ?? "이 음식 먹어도 되나요?");
}
