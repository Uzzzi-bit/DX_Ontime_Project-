import 'package:flutter/material.dart';

class ColorPalette {
  // Primary 색상
  static const Color primary100 = Color(0xFF3F51B5); // Primary 100
  static const Color primary200 = Color(0xFF757de8); // Primary 200
  static const Color primary300 = Color(0xFFdedeff); // Primary 300

  // Accent 색상
  static const Color accent100 = Color(0xFF2196F3); // Accent 100
  static const Color accent200 = Color(0xFF003f8f); // Accent 200

  // 텍스트 색상
  static const Color text100 = Color(0xFF333333); // Text 100
  static const Color text200 = Color(0xFF5c5c5c); // Text 200

  // 배경 색상
  static const Color bg100 = Color(0xFFFFFFFF); // Background 100
  static const Color bg200 = Color(0xFFf5f5f5); // Background 200
  static const Color bg300 = Color(0xFFcccccc); // Background 300

  // 하위 호환성을 위한 별칭
  static const Color primary = primary100;
  static const Color secondary = accent100;
  static const Color background = bg200;
  static const Color surface = bg100;
  static const Color textPrimary = text100;
  static const Color textSecondary = text200;
  static const Color textWhite = bg100;
}
