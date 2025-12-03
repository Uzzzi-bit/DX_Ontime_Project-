// lib/api/can_eat_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/gemini_config.dart'; // ✅ 설정 파일 import

/// 🔗 AI 백엔드 기본 URL
/// kAiBaseUrl은 gemini_config.dart에서 가져옵니다.

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

/// 공통 요청 함수
Future<CanEatResponse> fetchCanEat({
  String? query,
  XFile? imageFile,
  String? nickname,
  int? week,
  double? bmi,
  String? conditions,
}) async {
  // ✅ gemini_config.dart의 kAiBaseUrl 사용
  final uri = Uri.parse('$kAiBaseUrl/api/can-eat');

  try {
    final request = http.MultipartRequest('POST', uri);

    // ✅ [추가됨] 헤더에 API 키 추가
    // 백엔드 인증 방식에 따라 'Authorization' 혹은 'x-api-key' 등을 사용합니다.
    request.headers['Authorization'] = 'Bearer ${GeminiConfig.apiKey}';

    // 만약 백엔드가 'x-api-key'라는 이름을 원한다면 아래 주석을 풀고 위 코드를 주석 처리하세요.
    // request.headers['x-api-key'] = GeminiConfig.apiKey;

    // 🔤 텍스트 필드들 (있을 때만 세팅)
    if (query != null && query.trim().isNotEmpty) {
      request.fields['query'] = query.trim();
    }
    if (nickname != null && nickname.isNotEmpty) {
      request.fields['nickname'] = nickname;
    }
    if (week != null) {
      request.fields['week'] = week.toString();
    }
    if (bmi != null) {
      request.fields['bmi'] = bmi.toStringAsFixed(1);
    }
    if (conditions != null && conditions.isNotEmpty) {
      request.fields['conditions'] = conditions;
    }

    // 🖼 이미지 파일 (있을 때만 첨부)
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    // ⚠️ query도 없고 image도 없으면 요청 안 보냄
    if (request.fields.isEmpty && request.files.isEmpty) {
      return CanEatResponse(
        status: 'error',
        headline: '질문 또는 사진이 필요해요.',
        reason: '음식 사진을 올리거나, "○○ 먹어도 돼?"처럼 질문을 입력해 주세요.',
        targetType: '',
        itemName: '',
      );
    }

    // ⏳ 전송 + 타임아웃
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 15),
    );
    final resp = await http.Response.fromStream(streamedResponse);

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
    // 백엔드 꺼져 있거나 네트워크 에러일 때
    return CanEatResponse(
      status: 'error',
      headline: '분석에 실패했어요.',
      reason: '네트워크 상태를 확인하거나, 잠시 후 다시 시도해주세요.',
      targetType: '',
      itemName: '',
    );
  }
}

/// ✍️ 텍스트만 보낼 때 편하게 쓰는 헬퍼
Future<CanEatResponse> fetchCanEatFromText(String query) {
  return fetchCanEat(query: query);
}

/// 🖼 이미지(+선택 텍스트)로 보낼 때 편하게 쓰는 헬퍼
Future<CanEatResponse> fetchCanEatFromImage(
  XFile imageFile, {
  String? query,
}) {
  return fetchCanEat(
    query: query,
    imageFile: imageFile,
  );
}
