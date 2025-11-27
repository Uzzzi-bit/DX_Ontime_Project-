import 'package:flutter/material.dart';
import '../widget/bottom_bar_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        title: Text(
          '홈',
          style: Theme.of(context).textTheme.bodyMedium, // 테마에서 불러오기
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E1E1E)),
      ),
      body: Center(
        child: Text(
          '홈 화면이 준비 중입니다.',
          style: Theme.of(context).textTheme.displayMedium, // 테마에서 불러오기
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/'),
    );
  }
}
