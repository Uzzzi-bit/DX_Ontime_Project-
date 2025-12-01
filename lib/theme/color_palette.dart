import 'package:flutter/material.dart';

class ColorPalette {
  // 메인 키 컬러 (하늘색 계열)
  static const Color primary100 = Color(0xFFBCE7F0); // 메인 키 컬러 #BCE7F0
  static const Color primary200 = Color(0xFF5BB5C8); // 버튼 필요시 #5BB5C8 (진한 하늘색)
  static const Color primary300 = Color(0xFF3A8FA8); // 더 진한 하늘색 (진행 바 등)

  // 그라데이션 색상 (노란색 -> 녹색 -> 하늘색)
  static const Color gradientYellow = Color(0xFFFEF493); // 그라데이션 #FEF493
  static const Color gradientGreen = Color(0xFFD2ECBF); // 그라데이션 #D2ECBF
  static const Color gradientGreenMid = Color(0xFFDDEDC1); // 중간 녹색 (그라데이션 중간)
  static const Color gradientBlue = Color(0xFFBCE7F0); // 메인 키 컬러 (그라데이션 끝)

  // 그라데이션 색상 리스트 (칼로리 게이지 등에서 사용)
  static const List<Color> gradientColors = [
    gradientYellow, // 노란색
    gradientGreenMid, // 중간 녹색
    gradientBlue, // 하늘색 (메인 키 컬러)
  ];

  // 텍스트 색상
  static const Color text100 = Color(0xFF0F0F0F); // 글씨체 등 블랙 #0F0F0F
  static const Color text200 = Color(0xFF49454F); // 중간 회색 텍스트
  static const Color text300 = Color(0xFF5c5c5c); // 연한 회색 텍스트

  // 배경 색상
  static const Color bg100 = Color(0xFFFFFFFF); // 흰색 배경
  static const Color bg200 = Color(0xFFF7F7F7); // 기본회색 #F7F7F7
  static const Color bg300 = Color(0xFFF0ECE4); // 위젯박스 #F0ECE4 (베이지/아이보리)

  // 하위 호환성을 위한 별칭
  static const Color primary = primary100;
  static const Color secondary = primary200;
  static const Color background = bg200;
  static const Color surface = bg100;
  static const Color textPrimary = text100;
  static const Color textSecondary = text200;
  static const Color textWhite = bg100;
}
