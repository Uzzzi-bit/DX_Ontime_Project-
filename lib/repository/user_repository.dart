import '../model/user_model.dart';

class UserRepository {
  // TODO: CONNECT TO DJANGO BACKEND
  // 서버 연동 시 이 함수를 실제 API 호출로 대체
  static Future<UserModel> getDummyUser() async {
    // Mock 데이터 반환
    await Future.delayed(const Duration(milliseconds: 300)); // 네트워크 지연 시뮬레이션

    return UserModel(
      nickname: '김레제',
      pregnancyWeek: 20,
      statusMessage: '건강한 임신 생활을 응원합니다!',
      dueDate: DateTime(2026, 7, 1),
    );
  }
}
