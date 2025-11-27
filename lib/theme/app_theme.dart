import 'package:flutter/material.dart';
import 'package:prototype/theme/color_palette.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'ProductSans',
      scaffoldBackgroundColor: ColorPalette.bg200,
      appBarTheme: AppBarTheme(
        backgroundColor: ColorPalette.bg100,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: ColorPalette.text100,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        shape: const Border(
          bottom: BorderSide(
            color: ColorPalette.bg300,
            width: 0.5,
          ),
        ),
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 8,
      ),

      // Material 3 TextTheme 설정
      textTheme: const TextTheme(
        // 본문 텍스트 스타일
        bodyLarge: TextStyle(
          color: ColorPalette.text100,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: ColorPalette.text100,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: ColorPalette.text200,
          fontSize: 12,
          height: 1.3,
        ),

        // 제목 텍스트 스타일
        titleLarge: TextStyle(
          color: ColorPalette.text100,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: ColorPalette.text100,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: ColorPalette.text100,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Card 테마 설정
      cardTheme: CardThemeData(
        color: ColorPalette.primary100, // 카드 배경: primary
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ColorScheme 설정
      colorScheme: ColorScheme.light(
        // 기본 색상
        primary: ColorPalette.primary100,
        secondary: ColorPalette.accent100,
        tertiary: ColorPalette.primary200,
        error: Colors.red.shade700,
        background: ColorPalette.bg200,
        surface: ColorPalette.bg100,
        surfaceVariant: ColorPalette.bg200.withOpacity(0.95),

        // 텍스트/아이콘 색상
        onPrimary: ColorPalette.bg200, // primary 위 텍스트: bg200
        onSecondary: ColorPalette.bg100,
        onTertiary: ColorPalette.bg100,
        onBackground: ColorPalette.text100,
        onSurface: ColorPalette.text100,
        onSurfaceVariant: ColorPalette.text200,
        onError: ColorPalette.bg100,

        // 구분선 및 기타
        outline: ColorPalette.bg300,
        outlineVariant: ColorPalette.bg300.withOpacity(0.5),
      ),
    );
  }
}
