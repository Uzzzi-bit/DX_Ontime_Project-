// lib/api/recommendation_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../page/recipe_pages.dart'; // RecipeData import

class RecommendationApiService {
  static final RecommendationApiService instance = RecommendationApiService._internal();
  factory RecommendationApiService() => instance;
  RecommendationApiService._internal();

  /// AI 추천 레시피를 DB에 저장
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [recommendationDate] "2024-12-04" 형식의 날짜 문자열
  /// [bannerMessage] AI 추천 배너 메시지
  /// [recipes] AI 추천 레시피 리스트
  /// 
  /// 반환: {"success": true, "rec_id": 123, "recommendation_date": "2024-12-04", "recipes_count": 3}
  Future<Map<String, dynamic>> saveRecommendations({
    required String memberId,
    required String recommendationDate,
    required String bannerMessage,
    required List<RecipeData> recipes,
  }) async {
    try {
      // RecipeData를 JSON 형식으로 변환
      final recipesJson = recipes.map((recipe) => {
        'title': recipe.title,
        'fullTitle': recipe.fullTitle,
        'imagePath': recipe.imagePath,
        'ingredients': recipe.ingredients,
        'cookingSteps': recipe.cookingSteps,
        'tip': recipe.tip,
        'isOvenAvailable': recipe.isOvenAvailable,
        'ovenMode': recipe.ovenMode,
        'ovenTimeMinutes': recipe.ovenTimeMinutes,
        'calories': recipe.calories,
        'tags': recipe.tags,
      }).toList();

      final body = jsonEncode({
        'member_id': memberId,
        'recommendation_date': recommendationDate,
        'banner_message': bannerMessage,
        'recipes': recipesJson,
      });

      print('📤 [RecommendationApiService] 레시피 저장 요청:');
      print('   member_id: $memberId');
      print('   recommendation_date: $recommendationDate');
      print('   recipes 개수: ${recipes.length}');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/recommendations/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ [RecommendationApiService] 레시피 저장 성공: rec_id=${result['rec_id']}');
        return result;
      } else {
        print('❌ [RecommendationApiService] 레시피 저장 실패: ${response.statusCode} - ${response.body}');
        throw Exception('레시피 저장 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ [RecommendationApiService] 레시피 저장 중 오류: $e');
      rethrow;
    }
  }

  /// 특정 날짜의 AI 추천 레시피 조회
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [date] "2024-12-04" 형식의 날짜 문자열
  /// 
  /// 반환: {
  ///   "success": true,
  ///   "date": "2024-12-04",
  ///   "banner_message": "추천 배너 메시지",
  ///   "recipes": [...],
  ///   "recipes_count": 3
  /// }
  Future<Map<String, dynamic>> getRecommendations({
    required String memberId,
    required String date,
  }) async {
    try {
      print('📤 [RecommendationApiService] 레시피 조회 요청:');
      print('   member_id: $memberId');
      print('   date: $date');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/recommendations/$memberId/$date/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ [RecommendationApiService] 레시피 조회 성공: recipes_count=${result['recipes_count'] ?? 0}');
        return result;
      } else if (response.statusCode == 404) {
        // 레시피가 없으면 빈 결과 반환
        print('⚠️ [RecommendationApiService] 해당 날짜에 레시피 없음');
        return {
          'success': false,
          'date': date,
          'banner_message': null,
          'recipes': [],
          'recipes_count': 0,
        };
      } else {
        print('❌ [RecommendationApiService] 레시피 조회 실패: ${response.statusCode} - ${response.body}');
        throw Exception('레시피 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ [RecommendationApiService] 레시피 조회 중 오류: $e');
      rethrow;
    }
  }
}

