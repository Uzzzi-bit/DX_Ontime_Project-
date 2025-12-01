import 'package:flutter/material.dart';
import 'package:prototype/theme/color_palette.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'ProductSans',
      scaffoldBackgroundColor: ColorPalette.bg100, // 흰색 배경
      appBarTheme: AppBarTheme(
        backgroundColor: ColorPalette.bg100, // 흰색 배경
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: ColorPalette.text100, // 블랙 #0F0F0F
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        shape: const Border(
          bottom: BorderSide(
            color: ColorPalette.bg300, // 위젯박스 #F0ECE4
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
        color: ColorPalette.bg100, // 카드 배경: 흰색
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: ColorPalette.bg300, // 위젯박스 테두리 #F0ECE4
            width: 1,
          ),
        ),
      ),

      // ColorScheme 설정
      colorScheme: ColorScheme.light(
        // 기본 색상
        primary: ColorPalette.primary100, // 메인 키 컬러 #BCE7F0
        secondary: ColorPalette.primary200, // 버튼 필요시 #5BB5C8
        tertiary: ColorPalette.gradientGreen, // 그라데이션 녹색
        error: Colors.red.shade700,
        background: ColorPalette.bg100, // 흰색 배경
        surface: ColorPalette.bg100, // 흰색 표면
        surfaceVariant: ColorPalette.bg200, // 기본회색 #F7F7F7
        // 텍스트/아이콘 색상
        onPrimary: ColorPalette.text100, // primary 위 텍스트: 블랙
        onSecondary: ColorPalette.bg100, // secondary 위 텍스트: 흰색
        onTertiary: ColorPalette.text100,
        onBackground: ColorPalette.text100, // 배경 위 텍스트: 블랙 #0F0F0F
        onSurface: ColorPalette.text100, // 표면 위 텍스트: 블랙
        onSurfaceVariant: ColorPalette.text200, // 표면 변형 위 텍스트: 중간 회색
        onError: ColorPalette.bg100,

        // 구분선 및 기타
        outline: ColorPalette.bg300, // 위젯박스 #F0ECE4
        outlineVariant: ColorPalette.bg300.withOpacity(0.5),
      ),
    );
  }
}
