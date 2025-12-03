// lib/api/can_eat_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// 🔗 AI 백엔드 기본 URL
///
/// - Flutter Web / iOS 시뮬레이터에서 로컬 FastAPI 쓸 때:  http://localhost:8000
/// - Android 에뮬레이터에서 로컬 FastAPI 쓸 때:        http://10.0.2.2:8000
const String kAiBaseUrl = 'http://localhost:8000';

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
///
/// - query만 있을 수도 있고
/// - imageFile만 있을 수도 있고
/// - query + imageFile 둘 다 있을 수도 있음
///
/// 백엔드 쪽 스펙:
/// - POST /api/can-eat (multipart/form-data)
///   - fields:
///     - query (optional)
///     - nickname (optional)
///     - week (optional)
///     - bmi (optional)
///     - conditions (optional)
///   - files:
///     - image (optional)
Future<CanEatResponse> fetchCanEat({
  String? query,
  XFile? imageFile,
  String? nickname,
  int? week,
  double? bmi,
  String? conditions,
}) async {
  final uri = Uri.parse('$kAiBaseUrl/api/can-eat');

  try {
    final request = http.MultipartRequest('POST', uri);

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
