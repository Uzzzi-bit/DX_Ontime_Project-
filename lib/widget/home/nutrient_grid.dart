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
      if (i % 2 == 0)
        leftItems.add(nutrients[i]);
      else
        rightItems.add(nutrients[i]);
    }

    // 2. 레이아웃 빌더 (부모 크기 확인)
    return LayoutBuilder(
      builder: (context, constraints) {
        // 전체 크기를 줄이기 위해 기준 너비를 280px로 축소
        const double fixedMobileWidth = 280.0;

        // 간격과 바 길이 계산 (축소된 280px 기준)
        final gap = 8.0; // 중앙 간격 8px로 축소 (12 -> 8)
        final columnWidth = (fixedMobileWidth - gap) / 2;
        final maxGaugeWidth = columnWidth * 0.35; // 게이지 바 길이 비율 축소 (0.38 -> 0.35)

        // 전체를 Padding으로 감싸서 왼쪽 공간을 줄이고 오른쪽으로 이동
        return SizedBox(
          width: fixedMobileWidth,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // 세로 가운데 정렬
              children: [
                // [왼쪽 열]
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center, // 세로 가운데 정렬
                    children: leftItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == leftItems.length - 1;

                      return Padding(
                        padding: EdgeInsets.only(
                          top: isFirst ? 0 : ResponsiveHelper.height(context, 0.01),
                          bottom: isLast ? 0 : ResponsiveHelper.height(context, 0.01),
                        ),
                        child: _buildNutrientItem(
                          context,
                          item,
                          isLeft: true,
                          maxGaugeWidth: maxGaugeWidth,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // [중앙 간격]
                SizedBox(width: gap),

                // [오른쪽 열]
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center, // 세로 가운데 정렬
                    children: rightItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == rightItems.length - 1;

                      return Padding(
                        padding: EdgeInsets.only(
                          top: isFirst ? 0 : ResponsiveHelper.height(context, 0.01),
                          bottom: isLast ? 0 : ResponsiveHelper.height(context, 0.01),
                        ),
                        child: _buildNutrientItem(
                          context,
                          item,
                          isLeft: false,
                          maxGaugeWidth: maxGaugeWidth,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutrientItem(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool isLeft,
    required double maxGaugeWidth,
  }) {
    final label = item['label'] as String;
    final progress = (item['progress'] as num? ?? 0).toDouble();
    final clampedProgress = progress.clamp(0.0, 100.0);

    // 텍스트 너비 설정 - 크기 축소에 맞춰 조정
    final labelWidth = ResponsiveHelper.width(context, isLeft ? 0.07 : 0.10);
    // 텍스트와 바 사이 간격 축소
    final spacing = ResponsiveHelper.width(context, 0.005);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. 텍스트 - 최소 너비 보장하여 잘리지 않도록
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: labelWidth,
          ),
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: ResponsiveHelper.fontSize(context, 11), // 폰트 크기 축소 (11 -> 10)
              fontWeight: FontWeight.bold,
              color: const Color(0xFF000000),
              letterSpacing: 1.2, // 자간 최대한 늘리기
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 텍스트와 바 사이 간격
        SizedBox(width: spacing),

        // 2. 게이지 바 - 고정 너비로 설정하여 6개 모두 같은 길이 보장
        SizedBox(
          width: ResponsiveHelper.width(context, 0.15), // 모든 게이지 바가 동일한 최대 너비 사용
          height: ResponsiveHelper.height(context, 0.030), // 높이 축소 (0.038 -> 0.030)
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ResponsiveHelper.height(context, 0.025)), // 둥근 모서리 축소
            child: Stack(
              children: [
                // 빈 게이지 배경
                Container(
                  width: double.infinity,
                  height: ResponsiveHelper.height(context, 0.030), // 높이 축소 (0.038 -> 0.030)
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
                      fontSize: ResponsiveHelper.fontSize(context, 9), // 폰트 크기 축소 (9 -> 8)
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0, // 자간 최대한 늘리기
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
      ],
    );
  }
}
