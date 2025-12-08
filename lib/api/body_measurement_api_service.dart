// lib/api/body_measurement_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class BodyMeasurementApiService {
  static final BodyMeasurementApiService instance = BodyMeasurementApiService._internal();
  factory BodyMeasurementApiService() => instance;
  BodyMeasurementApiService._internal();

  /// 신체 변화 측정 기록 저장
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [measurementDate] 측정 날짜 (YYYY-MM-DD)
  /// [weightKg] 체중 (kg, 선택)
  /// [bloodSugarFasting] 공복 혈당 (mg/dL, 선택)
  /// [bloodSugarPostprandial] 식후 혈당 (mg/dL, 선택)
  /// [memo] 메모 (선택)
  /// [measurementId] 기존 기록 ID (업데이트 시 사용)
  Future<Map<String, dynamic>> saveBodyMeasurement({
    required String memberId,
    required String measurementDate,
    double? weightKg,
    int? bloodSugarFasting,
    int? bloodSugarPostprandial,
    String? memo,
    int? measurementId,
  }) async {
    try {
      final body = <String, dynamic>{
        'member_id': memberId,
        'measurement_date': measurementDate,
      };

      if (weightKg != null) {
        body['weight_kg'] = weightKg;
      }
      if (bloodSugarFasting != null) {
        body['blood_sugar_fasting'] = bloodSugarFasting;
      }
      if (bloodSugarPostprandial != null) {
        body['blood_sugar_postprandial'] = bloodSugarPostprandial;
      }
      if (memo != null && memo.isNotEmpty) {
        body['memo'] = memo;
      }

      http.Response response;
      if (measurementId != null) {
        // 업데이트: PUT 요청
        response = await http.put(
          Uri.parse('$apiBaseUrl/api/body-measurements/$measurementId/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      } else {
        // 생성: POST 요청
        response = await http.post(
          Uri.parse('$apiBaseUrl/api/body-measurements/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('신체 변화 기록 저장 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('신체 변화 기록 저장 중 오류: $e');
    }
  }

  /// 신체 변화 측정 기록 조회 (기간별)
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [startDate] 시작 날짜 (YYYY-MM-DD, 선택)
  /// [endDate] 종료 날짜 (YYYY-MM-DD, 선택)
  Future<Map<String, dynamic>> getBodyMeasurements({
    required String memberId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '$apiBaseUrl/api/body-measurements/$memberId/';
      final queryParams = <String, String>{};
      
      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('신체 변화 기록 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('신체 변화 기록 조회 중 오류: $e');
    }
  }

  /// 특정 날짜의 신체 변화 측정 기록 조회
  /// 
  /// [memberId] 사용자 Firebase UID
  /// [date] 날짜 (YYYY-MM-DD)
  Future<Map<String, dynamic>> getBodyMeasurementByDate({
    required String memberId,
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/body-measurements/$memberId/$date/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('신체 변화 기록 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('신체 변화 기록 조회 중 오류: $e');
    }
  }

  /// 신체 변화 측정 기록 삭제
  /// 
  /// [measurementId] 삭제할 기록 ID
  Future<void> deleteBodyMeasurement({
    required int measurementId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/api/body-measurements/$measurementId/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('신체 변화 기록 삭제 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('신체 변화 기록 삭제 중 오류: $e');
    }
  }
}

