class UserModel {
  final String nickname;
  final int pregnancyWeek;
  final String statusMessage;
  final DateTime? dueDate;

  UserModel({
    required this.nickname,
    required this.pregnancyWeek,
    required this.statusMessage,
    this.dueDate,
  });

  // JSON 직렬화 (서버 연동 시 사용)
  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'pregnancyWeek': pregnancyWeek,
      'statusMessage': statusMessage,
      'dueDate': dueDate?.toIso8601String(),
    };
  }

  // JSON 역직렬화 (서버 연동 시 사용)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      nickname: json['nickname'] as String,
      pregnancyWeek: json['pregnancyWeek'] as int,
      statusMessage: json['statusMessage'] as String,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
    );
  }
}
