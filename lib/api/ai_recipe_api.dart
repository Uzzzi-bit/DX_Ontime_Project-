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
  required double weight, // kg
  required double height, // cm
  required String conditions,
  required List<String> allergies, // 알러지 리스트
  // 모든 영양소 데이터를 Map으로 전달 (키: 영양소명, 값: {current: double, ratio: double})
  Map<String, Map<String, double>>? nutrients,
}) async {
  // BMI 계산: weight / (height * 0.01)^2
  final bmi = height > 0 ? weight / ((height * 0.01) * (height * 0.01)) : 22.0;
  // ✅ gemini_config.dart의 kAiBaseUrl 사용
  final uri = Uri.parse('$kAiBaseUrl/api/recommend-recipes');

  // 영양소 데이터를 JSON 형식으로 변환
  // 프롬프트에 필요한 모든 영양소를 포함 (섭취량이 0이어도 포함)
  final nutrientsData = <String, dynamic>{};
  if (nutrients != null) {
    nutrients.forEach((key, value) {
      // vitamin_b12를 vitamin_b로 매핑 (프롬프트는 vitamin_b를 사용)
      final apiKey = key == 'vitamin_b12' ? 'vitamin_b' : key;
      nutrientsData['today_$apiKey'] = value['current'] ?? 0;

      // 비율 키 이름도 프롬프트에 맞게 변환
      if (key == 'vitamin_b12') {
        nutrientsData['today_vita_b_ratio'] = value['ratio'] ?? 0;
      } else if (key == 'vitamin_a') {
        nutrientsData['today_vita_a_ratio'] = value['ratio'] ?? 0;
      } else if (key == 'vitamin_c') {
        nutrientsData['today_vita_c_ratio'] = value['ratio'] ?? 0;
      } else if (key == 'vitamin_d') {
        nutrientsData['today_vita_d_ratio'] = value['ratio'] ?? 0;
      } else if (key == 'dietary_fiber') {
        nutrientsData['today_fiber_ratio'] = value['ratio'] ?? 0;
      } else {
        nutrientsData['today_${apiKey}_ratio'] = value['ratio'] ?? 0;
      }
    });
  }

  final body = jsonEncode({
    "nickname": nickname,
    "week": week,
    "bmi": bmi,
    "conditions": conditions,
    "allergies": allergies, // 알러지 리스트 추가
    // report_pages.dart에서 계산된 모든 영양소 값 전달
    ...nutrientsData,
  });

  // 디버그: 전송되는 데이터 확인
  print('🔍 [AI Recipe API] 요청 데이터:');
  print('  - nickname: $nickname');
  print('  - week: $week');
  print('  - weight: $weight kg, height: $height cm');
  print('  - bmi: $bmi (계산됨)');
  print('  - conditions: $conditions');
  print('  - allergies: $allergies');
  print('  - nutrients: ${nutrientsData.keys.toList()}');
  if (nutrientsData.isNotEmpty) {
    print('  - 영양소 상세:');
    nutrientsData.forEach((key, value) {
      print('    $key: $value');
    });
  }

  try {
    print('📤 [AI Recipe API] 요청 전송 중...');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // ✅ [추가됨] 헤더에 API 키 추가
        'Authorization': 'Bearer ${GeminiConfig.apiKey}',
      },
      body: body,
    );

    print('📥 [AI Recipe API] 응답 수신: status=${resp.statusCode}');
    print(
      '📥 [AI Recipe API] 응답 본문 (처음 500자): ${resp.body.length > 500 ? resp.body.substring(0, 500) + "..." : resp.body}',
    );

    if (resp.statusCode != 200) {
      print('❌ [AI Recipe API] HTTP 에러: status=${resp.statusCode}');
      print('❌ [AI Recipe API] 응답 본문: ${resp.body}');
      throw Exception('status: ${resp.statusCode}, body: ${resp.body}');
    }

    // 응답 본문 전체 확인 (디버그용)
    print('📥 [AI Recipe API] 응답 본문 전체 길이: ${resp.body.length}');
    if (resp.body.length < 2000) {
      print('📥 [AI Recipe API] 응답 본문 전체: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    print('✅ [AI Recipe API] JSON 파싱 성공');
    print('  - decoded keys: ${decoded.keys.toList()}');
    print('  - bannerMessage: ${decoded['bannerMessage']}');
    print('  - recipes 타입: ${decoded['recipes'].runtimeType}');
    print('  - recipes 개수: ${(decoded['recipes'] as List?)?.length ?? 0}');

    final banner = decoded['bannerMessage'] as String? ?? '';
    final recipesJson = decoded['recipes'] as List<dynamic>? ?? [];

    if (recipesJson.isEmpty) {
      print('⚠️ [AI Recipe API] recipes 배열이 비어있습니다.');
      print('  - decoded keys: ${decoded.keys.toList()}');
      print('  - decoded[\'recipes\']: ${decoded['recipes']}');
    } else {
      print('✅ [AI Recipe API] recipes 배열에 ${recipesJson.length}개 항목 발견');
      // 첫 번째 레시피 상세 확인
      if (recipesJson.isNotEmpty) {
        final firstRecipe = recipesJson[0] as Map<String, dynamic>;
        print('  - 첫 번째 레시피 keys: ${firstRecipe.keys.toList()}');
        print('  - 첫 번째 레시피 title: ${firstRecipe['title']}');
        print('  - 첫 번째 레시피 isOvenAvailable: ${firstRecipe['isOvenAvailable']}');
      }
    }

    // JSON 리스트를 RecipeData 객체 리스트로 변환
    final recipes = <RecipeData>[];
    for (int i = 0; i < recipesJson.length; i++) {
      try {
        final recipeMap = recipesJson[i] as Map<String, dynamic>;
        print('🔄 [AI Recipe API] 레시피 ${i + 1} 파싱 시도...');
        print('  - recipe keys: ${recipeMap.keys.toList()}');
        final recipe = RecipeData.fromJson(recipeMap);
        recipes.add(recipe);
        print('  ✅ 레시피 ${i + 1} 파싱 성공: ${recipe.title}');
      } catch (e, stackTrace) {
        print('❌ [AI Recipe API] RecipeData 파싱 실패 (레시피 ${i + 1}):');
        print('  - 에러: $e');
        print('  - 스택 트레이스: $stackTrace');
        print('  - recipe JSON: ${recipesJson[i]}');
        // 파싱 실패한 레시피는 건너뛰고 계속 진행
        continue;
      }
    }

    print('✅ [AI Recipe API] 레시피 ${recipes.length}개 변환 완료');

    return AiRecipeResponse(
      bannerMessage: banner,
      recipes: recipes,
    );
  } catch (e, stackTrace) {
    // 에러 상세 정보 출력
    print('❌ [AI Recipe API] 에러 발생:');
    print('  - 에러 타입: ${e.runtimeType}');
    print('  - 에러 메시지: $e');
    print('  - 스택 트레이스: $stackTrace');
    // 백엔드가 아직 없거나 에러 나도 앱 안터지게 빈값 반환
    return AiRecipeResponse(
      bannerMessage: '',
      recipes: const [],
    );
  }
}
