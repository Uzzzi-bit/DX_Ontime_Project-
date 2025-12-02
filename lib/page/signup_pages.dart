// lib/page/signup_pages.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:prototype/api/member_api_service.dart';
import 'package:prototype/page/home_pages.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordCheck = _passwordCheckController.text;

    if (nickname.isEmpty || email.isEmpty || password.isEmpty || passwordCheck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임, 이메일, 비밀번호를 모두 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password != passwordCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1) Firebase Auth 회원가입
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final firebaseEmail = cred.user!.email ?? email;
      // 2) Django 서버에 uid 등록 (MemberApiService 사용)
      try {
        final result = await MemberApiService.instance.registerMember(
          uid,
          email: firebaseEmail,
          nickname: nickname,
        );
        debugPrint('registerMember result: $result');

        if (result['ok'] != true) {
          debugPrint('Django register_member error: $result');
        }
      } catch (e) {
        debugPrint('Django register_member exception: $e');
      }

      // 3) 홈으로 이동 (AuthWrapper 쓰면 거기 로직에 맞춰 변경 가능)
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String msg = '회원가입에 실패했습니다.';

      if (e.code == 'email-already-in-use') {
        msg = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        msg = '이메일 형식이 올바르지 않습니다.';
      } else if (e.code == 'weak-password') {
        msg = '비밀번호가 너무 약합니다. (6자 이상 권장)';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F3),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // LG 로고 (로그인과 동일하게)
              Image.asset(
                'assets/image/lg_logo.png',
                width: 500,
                height: 300,
              ),
              const SizedBox(height: 40),
              _buildNicknameField(),
              const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              _buildPasswordCheckField(),
              const SizedBox(height: 24),
              _buildSignUpButton(),
              const Spacer(),
              _buildBackToLoginButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNicknameField() {
    return TextField(
      controller: _nicknameController,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        hintText: '닉네임',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(width: 1.0, color: Colors.black26),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: '이메일',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(width: 1.0, color: Colors.black26),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPasswordCheckField() {
    return TextField(
      controller: _passwordCheckController,
      obscureText: true,
      decoration: InputDecoration(
        hintText: '비밀번호 확인',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(width: 1.0, color: Colors.black26),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSignUpButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signUp,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isLoading ? Colors.grey : const Color(0xFF2465D9),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '회원 가입',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBackToLoginButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // 로그인 화면으로 돌아가기
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(width: 1, color: Colors.black26),
        ),
        alignment: Alignment.center,
        child: const Text(
          '로그인으로 돌아가기',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
