import 'package:flutter/material.dart';
import '../../theme/color_palette.dart';
import '../../utils/responsive_helper.dart';

class NutrientGrid extends StatelessWidget {
  const NutrientGrid({
    super.key,
    required this.nutrients,
  });

  final List<Map<String, dynamic>> nutrients;

  @override
  Widget build(BuildContext context) {
    // 1. 데이터 분리
    final leftItems = <Map<String, dynamic>>[];
    final rightItems = <Map<String, dynamic>>[];

    for (int i = 0; i < nutrients.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(nutrients[i]);
      } else {
        rightItems.add(nutrients[i]);
      }
    }

    return Row(
      // [높이 맞춤] 좌우 컬럼의 높이를 강제로 맞춰서 'spaceBetween'이 정확히 동작하게 함
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // [왼쪽 열]
        Expanded(
          child: Column(
            // [핵심 1] 컬럼 내부 아이템들을 '좌측(Start)'으로 정렬
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 위아래 간격 균등 분배
            mainAxisSize: MainAxisSize.min,
            children: leftItems.map((item) => _buildNutrientItem(context, item, isLeft: true)).toList(),
          ),
        ),

        // [간격] (화면 크기에 비례) - 더 작게 조정
        SizedBox(width: ResponsiveHelper.width(context, 0.016)),

        // [오른쪽 열]
        Expanded(
          child: Column(
            // [핵심 1] 컬럼 내부 아이템들을 '좌측(Start)'으로 정렬
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: rightItems.map((item) => _buildNutrientItem(context, item, isLeft: false)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientItem(BuildContext context, Map<String, dynamic> item, {required bool isLeft}) {
    final label = item['label'] as String;
    final progress = (item['progress'] as num? ?? 0).toDouble();
    final clampedProgress = progress.clamp(0.0, 100.0);

    // 텍스트 너비 설정 (화면 크기에 비례) - 더 작게 조정
    final labelWidth = ResponsiveHelper.width(context, isLeft ? 0.07 : 0.11);

    return Row(
      mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 차지
      crossAxisAlignment: CrossAxisAlignment.center, // 텍스트와 바의 수직 중앙 정렬
      children: [
        // 1. 텍스트
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            // [핵심 2] 텍스트 박스 안에서 글자를 '좌측'으로 강제 정렬
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, 11),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF000000),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 텍스트와 바 사이 간격 (화면 크기에 비례) - 더 작게 조정
        SizedBox(width: ResponsiveHelper.width(context, 0.011)),

        // 2. 게이지 바 (화면 크기에 비례) - 더 작게 조정
        Flexible(
          child: SizedBox(
            height: ResponsiveHelper.height(context, 0.033),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveHelper.height(context, 0.033)),
              child: Stack(
                children: [
                  // 빈 게이지 배경
                  Container(
                    width: double.infinity,
                    height: ResponsiveHelper.height(context, 0.033),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F0F0), // 항상 연한 회색
                    ),
                  ),
                  // 채워지는 게이지
                  if (clampedProgress > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: clampedProgress / 100.0,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFEF493),
                                Color(0xFFDDEDC1),
                                Color(0xFFBCE7F0),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 퍼센트 텍스트 (항상 중앙 정렬)
                  Center(
                    child: Text(
                      '${clampedProgress.toInt()}%',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, 9),
                        fontWeight: FontWeight.w600,
                        color: clampedProgress == 0
                            ? const Color(0xFF808080) // 0%일 때 회색 텍스트
                            : ColorPalette.text100, // 게이지가 올라갔을 때 테마 블랙
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
