import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/image_model.dart';
import '../api/image_api_service.dart';

/// 이미지 정보를 Firestore에 저장/조회하는 Repository
class ImageRepository {
  static final ImageRepository _instance = ImageRepository._internal();
  factory ImageRepository() => _instance;
  ImageRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'images';

  /// 이미지 정보를 Firestore에 저장합니다.
  ///
  /// [imageModel] 저장할 이미지 모델
  /// Returns 생성된 문서 ID
  Future<String> saveImage(ImageModel imageModel) async {
    try {
      // 현재 사용자 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // Firestore에 저장
      final docRef = await _firestore.collection(_collectionName).add(imageModel.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('이미지 정보 저장 실패: $e');
    }
  }

  /// 이미지 정보를 업데이트합니다.
  ///
  /// [docId] Firestore 문서 ID
  /// [updates] 업데이트할 필드들
  Future<void> updateImage(String docId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collectionName).doc(docId).update(updates);
    } catch (e) {
      throw Exception('이미지 정보 업데이트 실패: $e');
    }
  }

  /// ingredient_info를 업데이트합니다.
  ///
  /// [docId] Firestore 문서 ID
  /// [ingredientInfo] JSON 형태의 분석 결과
  Future<void> updateIngredientInfo(String docId, String ingredientInfo) async {
    try {
      await updateImage(docId, {'ingredient_info': ingredientInfo});
    } catch (e) {
      throw Exception('ingredient_info 업데이트 실패: $e');
    }
  }

  /// 특정 사용자의 이미지 목록을 조회합니다.
  ///
  /// [memberId] 사용자 ID (Firebase UID)
  /// [imageType] 이미지 타입 필터 (선택사항)
  /// [limit] 최대 조회 개수 (선택사항)
  Future<List<ImageModel>> getImagesByMember({
    required String memberId,
    String? imageType,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection(_collectionName)
          .where('member_id', isEqualTo: memberId)
          .orderBy('created_at', descending: true);

      if (imageType != null) {
        query = query.where('image_type', isEqualTo: imageType);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ImageModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
    } catch (e) {
      throw Exception('이미지 목록 조회 실패: $e');
    }
  }

  /// 특정 이미지 정보를 조회합니다.
  ///
  /// [docId] Firestore 문서 ID
  Future<ImageModel?> getImageById(String docId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(docId).get();

      if (!doc.exists) {
        return null;
      }

      return ImageModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('이미지 조회 실패: $e');
    }
  }

  /// 이미지 정보를 삭제합니다.
  ///
  /// [docId] Firestore 문서 ID
  Future<void> deleteImage(String docId) async {
    try {
      await _firestore.collection(_collectionName).doc(docId).delete();
    } catch (e) {
      throw Exception('이미지 정보 삭제 실패: $e');
    }
  }

  /// 이미지 업로드 및 정보 저장을 한 번에 처리합니다.
  ///
  /// 이 메서드는 StorageService와 함께 사용되어야 합니다.
  /// StorageService로 이미지를 업로드한 후, 반환된 URL과 함께
  /// 이 메서드를 호출하여 Firestore에 메타데이터를 저장합니다.
  ///
  /// [imageUrl] Firebase Storage URL
  /// [imageType] 이미지 타입 ('meal', 'chat', 'recipe' 등)
  /// [source] 이미지 소스 ('ai_chat', 'meal_form', 'system' 등)
  /// [memberId] 업로드한 사용자 ID (선택사항 - 없으면 현재 사용자)
  /// [ingredientInfo] 분석 결과 JSON (선택사항)
  Future<String> saveImageWithUrl({
    required String imageUrl,
    required String imageType,
    required String source,
    String? memberId,
    String? ingredientInfo,
  }) async {
    try {
      // 현재 사용자 확인
      final user = FirebaseAuth.instance.currentUser;
      final String finalMemberId = memberId ?? user?.uid ?? '';

      if (finalMemberId.isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      // 이미지 모델 생성
      final imageModel = ImageModel(
        memberId: finalMemberId,
        imageUrl: imageUrl,
        ingredientInfo: ingredientInfo,
        imageType: imageType,
        source: source,
        createdAt: DateTime.now(),
      );

      // 1. Firestore에 저장
      final firestoreDocId = await saveImage(imageModel);

      // 2. Django DB에도 저장 (공용 DB 접근을 위해)
      try {
        await ImageApiService.instance.saveImage(
          memberId: finalMemberId,
          imageUrl: imageUrl,
          imageType: imageType,
          source: source,
          ingredientInfo: ingredientInfo,
        );
      } catch (e) {
        // Django 저장 실패해도 Firestore는 성공했으므로 계속 진행
        // 하지만 에러 로그는 남김
        debugPrint('⚠️ Django DB 저장 실패 (Firestore는 성공): $e');
      }

      return firestoreDocId;
    } catch (e) {
      throw Exception('이미지 정보 저장 실패: $e');
    }
  }
}
