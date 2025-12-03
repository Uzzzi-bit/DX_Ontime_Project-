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
    final url = Uri.parse('$apiBaseUrl/api/images/');

    final bodyMap = {
      'member_id': memberId,
      'image_url': imageUrl,
      'image_type': imageType,
      'source': source,
    };

    if (ingredientInfo != null) {
      bodyMap['ingredient_info'] = ingredientInfo;
    }

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('saveImage 실패: ${res.statusCode} $body');
    }

    return body;
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

