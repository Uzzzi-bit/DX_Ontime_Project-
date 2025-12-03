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
}) async {
  // ✅ gemini_config.dart의 kAiBaseUrl 사용
  final uri = Uri.parse('$kAiBaseUrl/api/recommend-recipes');

  final body = jsonEncode({
    "nickname": nickname,
    "week": week,
    "bmi": bmi,
    "conditions": conditions,
    // 지금은 영양소 더미 값 (나중에 실제로 연결)
    "today_carbs": 0,
    "today_carbs_ratio": 0,
    "today_protein": 0,
    "today_protein_ratio": 0,
    "today_fat": 0,
    "today_fat_ratio": 0,
    "today_sodium": 0,
    "today_sodium_ratio": 0,
    "today_calcium": 0,
    "today_calcium_ratio": 0,
    "today_iron": 0,
    "today_iron_ratio": 0,
  });

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
