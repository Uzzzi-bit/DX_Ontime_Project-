import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototype/page/home_pages.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({super.key});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 페이지의 뼈대를 그려주는 위젯
      appBar: AppBar(backgroundColor: const Color(0xFFF1F2F3)),
      backgroundColor: const Color(0xFFF1F2F3),
      body: SafeArea(
        // body는 페이지의 본문 내용
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              Image.asset('assets/image/LG_logo.png', width: 500, height: 300),
              Container(height: 26),
              Text(
                '보다 더 스마트한 일상\nLG ThinQ와 시작',
                style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Container(height: 46),
              _buildEmailField(),
              Container(height: 16),
              _buildNickNameField(),
              Container(height: 16),
              _buildPasswordField(),
              Container(height: 26),
              _buildSignUpButton(context),
              Container(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: '이메일',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(width: 1.0, color: Colors.black26),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildNickNameField() {
    return TextField(
      controller: _nickNameController,
      keyboardType: TextInputType.name,
      decoration: InputDecoration(
        hintText: '닉네임',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(width: 1.0, color: Colors.black26),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        hintText: '비밀번호',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(width: 1.0, color: Colors.black26),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSignUpButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 회원가입 처리
        _signUp(context);
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(color: const Color(0xFF2465D9), borderRadius: BorderRadius.circular(5)),
        alignment: Alignment.center,
        child: const Text(
          '회원 가입',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _signUp(BuildContext context) async {
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // 과제1: 회원가입 처리
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);

      // 과제2: 닉네임 업데이트
      final String displayName = _nickNameController.text.trim();
      await FirebaseAuth.instance.currentUser?.updateDisplayName(displayName);

      // 로그인 성공 시 피드 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return HomeScreen();
          },
        ),
      );
    } catch (e) {
      // 오류 처리
      print(e);
    }
  }
}
