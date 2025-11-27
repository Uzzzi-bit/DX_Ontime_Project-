import 'package:flutter/material.dart';
import 'package:prototype/page/add_family_pages.dart';
import 'package:prototype/page/analysis_pages.dart';
import 'package:prototype/page/health_info_pages.dart';
import 'package:prototype/page/mom_care_setting_pages.dart';
import 'package:prototype/page/recipe_pages.dart';
import 'package:prototype/theme/app_theme.dart';
import 'page/report_pages.dart';
import 'page/home_pages.dart';
import 'page/chat_pages.dart';
import 'page/setting_pages.dart';

void main() {
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
