import 'dart:convert';
import 'package:http/http.dart' as http;

// 레시피 API랑 같은 베이스 URL 사용
const String kAiBaseUrl = 'http://10.0.2.2:8000';

class CanEatResponse {
  final String status; // "ok" | "caution" | "avoid" | "error"
  final String headline; // 한 줄 요약
  final String reason; // 상세 이유
  final String targetType; // "food" | "supplement" 등
  final String itemName; // 분석 대상 이름

  CanEatResponse({
    required this.status,
    required this.headline,
    required this.reason,
    required this.targetType,
    required this.itemName,
  });
}

Future<CanEatResponse> fetchCanEatResult(String query) async {
  final uri = Uri.parse('$kAiBaseUrl/api/can-eat');

  try {
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query, // 사용자가 입력한 문장 전체
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('status=${resp.statusCode}, body=${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;

    return CanEatResponse(
      status: json['status']?.toString() ?? 'error',
      headline: json['headline']?.toString() ?? '분석에 실패했어요.',
      reason: json['reason']?.toString() ?? '잠시 후 다시 시도해주세요.',
      targetType: json['target_type']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
    );
  } catch (_) {
    // 백엔드 꺼져 있거나 에러 나도 앱 안 터지게
    return CanEatResponse(
      status: 'error',
      headline: '분석에 실패했어요.',
      reason: '네트워크 상태를 확인하거나, 잠시 후 다시 시도해주세요.',
      targetType: '',
      itemName: '',
    );
  }
}
