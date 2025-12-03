import 'package:flutter/material.dart';

/// 반응형 디자인을 위한 헬퍼 클래스
/// 화면 크기에 따라 동적으로 크기를 조정합니다.
class ResponsiveHelper {
  /// 화면 너비의 비율로 크기 반환
  static double width(BuildContext context, double ratio) {
    return MediaQuery.of(context).size.width * ratio;
  }

  /// 화면 높이의 비율로 크기 반환
  static double height(BuildContext context, double ratio) {
    return MediaQuery.of(context).size.height * ratio;
  }

  /// 화면 너비와 높이 중 작은 값의 비율로 크기 반환 (정사각형 등에 유용)
  static double size(BuildContext context, double ratio) {
    final size = MediaQuery.of(context).size;
    return (size.width < size.height ? size.width : size.height) * ratio;
  }

  /// 폰트 크기를 화면 크기에 비례하여 조정
  static double fontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    // 기준 너비 375 (iPhone X)를 기준으로 스케일링
    final scale = width / 375.0;
    return baseSize * scale.clamp(0.8, 1.2); // 최소 0.8배, 최대 1.2배
  }

  /// 패딩을 화면 크기에 비례하여 조정
  static EdgeInsets padding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 375.0).clamp(0.9, 1.1);
    
    if (all != null) {
      return EdgeInsets.all(all * scale);
    }
    
    return EdgeInsets.only(
      top: (top ?? vertical ?? 0) * scale,
      bottom: (bottom ?? vertical ?? 0) * scale,
      left: (left ?? horizontal ?? 0) * scale,
      right: (right ?? horizontal ?? 0) * scale,
    );
  }

  /// 화면 너비가 특정 값보다 작은지 확인 (모바일/태블릿 구분)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// 화면 너비가 특정 값보다 큰지 확인 (태블릿/데스크톱)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }
}

