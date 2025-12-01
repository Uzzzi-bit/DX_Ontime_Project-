import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';

// 페이지들
import 'page/home_pages.dart';
import 'page/chat_pages.dart';
import 'page/report_pages.dart';
import 'page/analysis_pages.dart';
import 'page/recipe_pages.dart';
import 'page/mom_care_setting_pages.dart';
import 'page/health_info_pages.dart';
import 'page/add_family_pages.dart';
import 'page/setting_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔹 임시로 익명 로그인 (회원가입 붙이기 전까지)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/chat': (_) => const ChatScreen(),
        '/report': (_) => const ReportScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/recipe': (_) => const RecipeScreen(),
        '/momcaresetting': (_) => const MomCareSettingScreen(),
        '/healthinfo': (_) => const HealthInfoScreen(),
        '/addfamily': (_) => const AddFamilyScreen(),
      },
    );
  }
}
