import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prototype/api_config.dart';

/// 이미지 API 서비스
/// Django 백엔드의 이미지 관련 API를 호출합니다.
class ImageApiService {
  ImageApiService._();
  static final ImageApiService instance = ImageApiService._();

  /// 이미지 정보를 Django DB에 저장합니다.
  /// 
  /// POST {apiBaseUrl}/api/images/
  /// body: {
  ///   "member_id": "firebase-uid",
  ///   "image_url": "https://...",
  ///   "image_type": "meal",
  ///   "source": "meal_form",
  ///   "ingredient_info": null
  /// }
  /// 
  /// Returns 저장된 이미지 정보 (image_id 포함)
  Future<Map<String, dynamic>> saveImage({
    required String memberId,
    required String imageUrl,
    required String imageType,
    required String source,
    String? ingredientInfo,
  }) async {
    try {
      final url = Uri.parse('$apiBaseUrl/api/images/');
      
      print('🌐 Django API 호출: $url');
      print('   요청 데이터:');
      print('   - member_id: $memberId');
      print('   - image_type: $imageType');
      print('   - source: $source');
      print('   - image_url 길이: ${imageUrl.length}');

      final bodyMap = {
        'member_id': memberId,
        'image_url': imageUrl,
        'image_type': imageType,
        'source': source,
      };

      if (ingredientInfo != null) {
        bodyMap['ingredient_info'] = ingredientInfo;
      }

      print('📤 POST 요청 전송 중...');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Django API 요청 타임아웃 (10초 초과)');
        },
      );

      print('📥 응답 수신: ${res.statusCode}');
      print('   응답 본문: ${res.body}');

      if (res.statusCode != 200 && res.statusCode != 201) {
        final errorBody = utf8.decode(res.bodyBytes);
        print('❌ Django API 오류 응답:');
        print('   상태 코드: ${res.statusCode}');
        print('   응답 본문: $errorBody');
        throw Exception('saveImage 실패: ${res.statusCode} $errorBody');
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      print('✅ Django API 성공: $body');
      
      return body;
    } catch (e) {
      print('❌ ImageApiService.saveImage 오류:');
      print('   오류: $e');
      print('   타입: ${e.runtimeType}');
      if (e is Exception) {
        print('   메시지: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// 이미지 정보를 업데이트합니다 (주로 ingredient_info 업데이트용).
  /// 
  /// PUT {apiBaseUrl}/api/images/{image_id}/
  /// body: {
  ///   "ingredient_info": "{...}"
  /// }
  Future<void> updateImage({
    required int imageId,
    String? ingredientInfo,
  }) async {
    final url = Uri.parse('$apiBaseUrl/api/images/$imageId/');

    final bodyMap = <String, dynamic>{};
    if (ingredientInfo != null) {
      bodyMap['ingredient_info'] = ingredientInfo;
    }

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );

    if (res.statusCode != 200) {
      throw Exception('updateImage 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 특정 사용자의 이미지 목록을 조회합니다.
  /// 
  /// GET {apiBaseUrl}/api/images/?member_id={memberId}&image_type={imageType}
  Future<List<Map<String, dynamic>>> getImages({
    required String memberId,
    String? imageType,
  }) async {
    var url = Uri.parse('$apiBaseUrl/api/images/?member_id=$memberId');
    
    if (imageType != null) {
      url = Uri.parse('$apiBaseUrl/api/images/?member_id=$memberId&image_type=$imageType');
    }

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('getImages 실패: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['results'] ?? body);
  }
}

