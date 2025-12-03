import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ intl: 한국어 날짜 포맷용
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';

// 페이지들
import 'page/home_pages.dart';
import 'page/login_pages.dart';
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

  // ✅ 한국어 날짜/요일 로케일 초기화 (여기가 추가된 부분)
  await initializeDateFormatting('ko_KR', null);

  // 🔹 Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      routes: {
        '/chat': (_) => const ChatScreen(),
        '/report': (_) => const ReportScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/recipe': (_) => const RecipeScreen(),
        '/momcaresetting': (_) => const MomCareSettingScreen(),
        '/healthinfo': (_) => const HealthInfoScreen(),
        '/addfamily': (_) => const AddFamilyScreen(),
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // FirebaseAuth로부터 현재 로그인한 사용자 정보를 가져옵니다.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 만약 사용자가 로그인하지 않은 상태라면 `LoginScreen`를 보여줍니다.
        if (snapshot.data == null) {
          return LoginScreen();
        }
        // 만약 사용자가 로그인한 상태라면 `HomeScreen`를 보여줍니다.
        return const HomeScreen();
      },
    );
  }
}
