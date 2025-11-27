import 'package:flutter/material.dart';
import 'package:prototype/page/analysis_pages.dart';
import 'package:prototype/page/recipe_pages.dart';
import 'package:prototype/theme/app_theme.dart';
import 'page/report_page.dart';
import 'page/home_page.dart';
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
      },
    );
  }
}
