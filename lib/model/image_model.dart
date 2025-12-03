/// 이미지 정보를 나타내는 모델 클래스
///
/// Firestore의 IMAGES 컬렉션과 매핑됩니다.
class ImageModel {
  final int? id; // DB의 자동 증가 ID (null 가능 - 생성 시)
  final int? imageId; // image_id (null 가능 - 생성 시)
  final String memberId; // 업로드한 사용자의 Firebase UID
  final String imageUrl; // Firebase Storage URL
  final String? ingredientInfo; // SAM3/분류모델 결과 (JSON 문자열, null 가능)
  final String imageType; // 'meal', 'chat', 'recipe' 등
  final String source; // 'ai_chat', 'meal_form', 'system' 등
  final DateTime createdAt; // 생성 시간

  ImageModel({
    this.id,
    this.imageId,
    required this.memberId,
    required this.imageUrl,
    this.ingredientInfo,
    required this.imageType,
    required this.source,
    required this.createdAt,
  });

  /// Firestore 문서를 Map으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'member_id': memberId,
      'image_url': imageUrl,
      'ingredient_info': ingredientInfo,
      'image_type': imageType,
      'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Firestore 문서에서 ImageModel 생성
  factory ImageModel.fromFirestore(Map<String, dynamic> doc, String docId) {
    return ImageModel(
      id: int.tryParse(docId),
      imageId: doc['image_id'] as int?,
      memberId: doc['member_id'] as String,
      imageUrl: doc['image_url'] as String,
      ingredientInfo: doc['ingredient_info'] as String?,
      imageType: doc['image_type'] as String,
      source: doc['source'] as String,
      createdAt: DateTime.parse(doc['created_at'] as String),
    );
  }

  /// JSON 직렬화 (API 통신 시 사용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_id': imageId,
      'member_id': memberId,
      'image_url': imageUrl,
      'ingredient_info': ingredientInfo,
      'image_type': imageType,
      'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// JSON 역직렬화 (API 통신 시 사용)
  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'] as int?,
      imageId: json['image_id'] as int?,
      memberId: json['member_id'] as String,
      imageUrl: json['image_url'] as String,
      ingredientInfo: json['ingredient_info'] as String?,
      imageType: json['image_type'] as String,
      source: json['source'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// ingredientInfo를 업데이트한 새 인스턴스 생성
  ImageModel copyWith({
    int? id,
    int? imageId,
    String? memberId,
    String? imageUrl,
    String? ingredientInfo,
    String? imageType,
    String? source,
    DateTime? createdAt,
  }) {
    return ImageModel(
      id: id ?? this.id,
      imageId: imageId ?? this.imageId,
      memberId: memberId ?? this.memberId,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredientInfo: ingredientInfo ?? this.ingredientInfo,
      imageType: imageType ?? this.imageType,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 이미지 타입 상수
class ImageType {
  static const String meal = 'meal';
  static const String chat = 'chat';
  static const String recipe = 'recipe';
}

/// 이미지 소스 상수
class ImageSourceType {
  static const String aiChat = 'ai_chat';
  static const String mealForm = 'meal_form';
  static const String system = 'system';
}
