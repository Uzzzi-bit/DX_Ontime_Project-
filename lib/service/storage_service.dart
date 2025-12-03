import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Storage에 이미지를 업로드하는 서비스
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 이미지를 Firebase Storage에 업로드하고 URL을 반환합니다.
  ///
  /// [imageFile] 업로드할 이미지 파일
  /// [folder] 저장할 폴더 경로 (예: 'meal_images', 'chat_images')
  /// [fileName] 파일명 (null이면 자동 생성)
  ///
  /// Returns 업로드된 이미지의 다운로드 URL
  Future<String> uploadImage({
    required File imageFile,
    required String folder,
    String? fileName,
  }) async {
    try {
      // 현재 사용자 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 파일명이 없으면 타임스탬프 기반 생성
      final String finalFileName =
          fileName ?? '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

      // 저장 경로: {folder}/{userId}/{fileName}
      final String storagePath = '$folder/${user.uid}/$finalFileName';

      // Firebase Storage 참조 생성
      final Reference ref = _storage.ref().child(storagePath);

      // 업로드 메타데이터 설정
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000', // 1년 캐시
      );

      // 업로드 실행
      final UploadTask uploadTask = ref.putFile(imageFile, metadata);

      // 업로드 진행률 모니터링 (선택사항)
      // uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      //   final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      //   print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      // });

      // 업로드 완료 대기
      final TaskSnapshot snapshot = await uploadTask;

      // 다운로드 URL 가져오기
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  /// 이미지를 삭제합니다.
  ///
  /// [imageUrl] 삭제할 이미지의 Storage URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      // URL에서 경로 추출
      final Uri uri = Uri.parse(imageUrl);
      final String path = uri.path.split('/o/').last.split('?').first;
      final String decodedPath = Uri.decodeComponent(path);

      // Storage 참조 생성 및 삭제
      final Reference ref = _storage.ref().child(decodedPath);
      await ref.delete();
    } catch (e) {
      throw Exception('이미지 삭제 실패: $e');
    }
  }
}
