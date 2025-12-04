import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/gemini_config.dart'; // ✅ 설정 파일 import
import '../page/recipe_pages.dart'; // RecipeData가 정의된 곳

class AiRecipeResponse {
  final String bannerMessage;
  final List<RecipeData> recipes;

  AiRecipeResponse({
    required this.bannerMessage,
    required this.recipes,
  });
}

Future<AiRecipeResponse> fetchAiRecommendedRecipes({
  required String nickname,
  required int week,
  required double bmi,
  required String conditions,
  // 모든 영양소 데이터를 Map으로 전달 (키: 영양소명, 값: {current: double, ratio: double})
  Map<String, Map<String, double>>? nutrients,
}) async {
  // ✅ gemini_config.dart의 kAiBaseUrl 사용
  final uri = Uri.parse('$kAiBaseUrl/api/recommend-recipes');

  // 영양소 데이터를 JSON 형식으로 변환
  final nutrientsData = <String, dynamic>{};
  if (nutrients != null) {
    nutrients.forEach((key, value) {
      nutrientsData['today_$key'] = value['current'] ?? 0;
      nutrientsData['today_${key}_ratio'] = value['ratio'] ?? 0;
    });
  }

  final body = jsonEncode({
    "nickname": nickname,
    "week": week,
    "bmi": bmi,
    "conditions": conditions,
    // report_pages.dart에서 계산된 모든 영양소 값 전달
    ...nutrientsData,
  });

  // 디버그: 전송되는 데이터 확인
  print('🔍 [AI Recipe API] 요청 데이터:');
  print('  - nickname: $nickname');
  print('  - week: $week');
  print('  - bmi: $bmi');
  print('  - conditions: $conditions');
  print('  - nutrients: ${nutrientsData.keys.toList()}');
  if (nutrientsData.isNotEmpty) {
    print('  - 영양소 상세:');
    nutrientsData.forEach((key, value) {
      print('    $key: $value');
    });
  }

  try {
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // ✅ [추가됨] 헤더에 API 키 추가
        'Authorization': 'Bearer ${GeminiConfig.apiKey}',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('status: ${resp.statusCode}, body: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final banner = decoded['bannerMessage'] as String? ?? '';
    final recipesJson = decoded['recipes'] as List<dynamic>? ?? [];

    // JSON 리스트를 RecipeData 객체 리스트로 변환
    final recipes = recipesJson.map((e) => RecipeData.fromJson(e as Map<String, dynamic>)).toList();

    return AiRecipeResponse(
      bannerMessage: banner,
      recipes: recipes,
    );
  } catch (_) {
    // 백엔드가 아직 없거나 에러 나도 앱 안터지게 빈값 반환
    return AiRecipeResponse(
      bannerMessage: '',
      recipes: const [],
    );
  }
}
