import 'package:flutter/material.dart';
import '../widget/bottom_bar_widget.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        automaticallyImplyLeading: false, // 자동 leading 생성 방지
        leading: IconButton(
          onPressed: () {
            // 이전 화면으로 돌아가기 (pop 가능한 경우에만)
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              // pop이 불가능한 경우 홈으로 이동
              Navigator.pushReplacementNamed(context, '/');
            }
          },
          icon: const Icon(Icons.keyboard_backspace),
        ),
        title: Text(
          '종합리포트',
          style: Theme.of(context).textTheme.bodyMedium, // 테마에서 불러오기
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E1E1E)),
      ),
      body: Center(
        child: Text(
          '종합리포트 화면이 준비 중입니다.',
          style: Theme.of(context).textTheme.displayMedium, // 테마에서 불러오기
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/report'),
    );
  }
}
