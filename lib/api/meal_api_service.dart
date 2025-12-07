import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class MealApiService {
  static final MealApiService instance = MealApiService._internal();
  factory MealApiService() => instance;
  MealApiService._internal();

  /// 이미지를 YOLO로 분석하여 음식 리스트 반환
  /// 
  /// [imageFile] 분석할 이미지 파일
  /// [memberId] 사용자 Firebase UID
  /// 
  /// 반환: {"success": true, "foods": [{"name": "apple", "confidence": 0.9}, ...], "count": 2}
  Future<Map<String, dynamic>> analyzeMealImage({
    required File imageFile,
    required String memberId,
  }) async {
    try {
      print('🔄 [MealApiService] 이미지 분석 시작');
      
      // 이미지 파일 존재 확인
      if (!await imageFile.exists()) {
        throw Exception('이미지 파일을 찾을 수 없습니다: ${imageFile.path}');
      }
      
      // 이미지를 Base64로 인코딩
      print('🔄 [MealApiService] 이미지를 Base64로 인코딩 중...');
      final imageBytes = await imageFile.readAsBytes();
      print('✅ [MealApiService] 이미지 읽기 완료 (크기: ${imageBytes.length} bytes)');
      
      final imageBase64 = base64Encode(imageBytes);
      print('✅ [MealApiService] Base64 인코딩 완료 (길이: ${imageBase64.length})');

      // Django API 호출
      print('🔄 [MealApiService] Django API 호출 중: $apiBaseUrl/api/meals/analyze/');
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/meals/analyze/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_base64': imageBase64,
          'member_id': memberId,
        }),
      ).timeout(const Duration(seconds: 60));

      print('📥 [MealApiService] 응답 수신: ${response.statusCode}');
      print('📥 [MealApiService] 응답 본문: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ [MealApiService] 이미지 분석 완료: success=${result['success']}, count=${result['count']}');
        return result;
      } else {
        final errorBody = response.body;
        print('❌ [MealApiService] 이미지 분석 실패: ${response.statusCode} - $errorBody');
        throw Exception('이미지 분석 실패: ${response.statusCode} ${errorBody}');
      }
    } catch (e) {
      print('❌ [MealApiService] 이미지 분석 중 오류: $e');
      rethrow;
    }
  }

  /// 식사 기록 저장
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [mealTime] "조식" | "중식" | "석식" | "야식"
  /// [mealDate] "2024-12-04" 형식의 날짜 문자열
  /// [imageId] 이미지 ID (선택사항)
  /// [memo] 메모 (선택사항)
  /// [foods] YOLO 분석 결과 음식 리스트 (선택사항)
  /// 
  /// 반환: {"success": true, "meal_id": 123, "total_nutrition": {...}, "foods_count": 2}
  Future<Map<String, dynamic>> saveMeal({
    required String memberId,
    required String mealTime,
    required String mealDate,
    int? imageId,
    String? memo,
    List<Map<String, dynamic>>? foods,
  }) async {
    try {
      final body = <String, dynamic>{
        'member_id': memberId,
        'meal_time': mealTime,
        'meal_date': mealDate,
      };

      if (imageId != null) {
        body['image_id'] = imageId;
      }
      if (memo != null && memo.isNotEmpty) {
        body['memo'] = memo;
      }
      if (foods != null && foods.isNotEmpty) {
        body['foods'] = foods;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/meals/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('식사 기록 저장 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('식사 기록 저장 중 오류: $e');
    }
  }

  /// 특정 날짜의 총 섭취 영양소 조회
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [date] "2024-12-04" 형식의 날짜 문자열
  /// 
  /// 반환: {
  ///   "success": true,
  ///   "date": "2024-12-04",
  ///   "total_nutrition": {...},
  ///   "meals": [...],
  ///   "meals_count": 2
  /// }
  Future<Map<String, dynamic>> getDailyNutrition({
    required String memberId,
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/meals/daily-nutrition/$memberId/$date/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('영양소 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('영양소 조회 중 오류: $e');
    }
  }

  /// 특정 날짜의 식사 기록 목록 조회
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [date] "2024-12-04" 형식의 날짜 문자열
  /// 
  /// 반환: {
  ///   "success": true,
  ///   "date": "2024-12-04",
  ///   "meals": [
  ///     {
  ///       "meal_id": 1,
  ///       "meal_time": "아침",
  ///       "memo": "김치찌개, 현미밥",
  ///       "image_id": 123,
  ///       "image_url": "https://...",
  ///       "foods": ["김치찌개", "현미밥"],
  ///       "created_at": "2024-12-04T12:00:00"
  ///     }
  ///   ],
  ///   "count": 1
  /// }
  Future<Map<String, dynamic>> getMeals({
    required String memberId,
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/meals/$memberId/$date/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('식사 기록 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('식사 기록 조회 중 오류: $e');
    }
  }

  /// 특정 날짜와 식사 타입의 모든 meal 삭제
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [date] "2024-12-04" 형식의 날짜 문자열
  /// [mealTime] "조식" | "중식" | "석식" | "야식"
  /// 
  /// 반환: {
  ///   "success": true,
  ///   "date": "2024-12-04",
  ///   "meal_time": "중식",
  ///   "deleted_count": 2
  /// }
  Future<Map<String, dynamic>> deleteMealsByDateAndType({
    required String memberId,
    required String date,
    required String mealTime,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/api/meals/$memberId/$date/$mealTime/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('식사 기록 삭제 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('식사 기록 삭제 중 오류: $e');
    }
  }
}

