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
        // [핵심 해결책]
        // 화면이 아무리 넓어도 계산 기준을 '340px' (일반 폰 너비)로 고정합니다.
        // 웹에서는 이보다 넓겠지만, 우리는 340px 기준으로만 그립니다.
        const double fixedMobileWidth = 340.0;

        // 간격과 바 길이 계산 (고정된 340px 기준으로 계산하므로 웹에서도 안 늘어남)
        final gap = 12.0; // 중앙 간격 12px 고정
        final columnWidth = (fixedMobileWidth - gap) / 2;
        final maxGaugeWidth = columnWidth * 0.38; // 게이지 바 길이 비율 (절반으로 줄임)

        // 전체를 Padding으로 감싸서 왼쪽 공간을 줄이고 오른쪽으로 이동
        return Padding(
          padding: EdgeInsets.only(
            left: ResponsiveHelper.width(context, 0.01), // 왼쪽 패딩 더 줄이기 (0.02 -> 0.01)
            right: ResponsiveHelper.width(context, 0.01),
          ),
          child: SizedBox(
            width: fixedMobileWidth, // ★ 전체 폭을 340px로 강제 고정!
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // [왼쪽 열]
                Expanded(
                  // 340px 안에서의 절반 차지
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 최소 크기만 차지
                    crossAxisAlignment: CrossAxisAlignment.end, // 오른쪽(중앙)으로 붙이기
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 위아래 간격 균등 분배
                    children: leftItems
                        .map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: ResponsiveHelper.height(context, 0.005)), // 간격 줄이기
                            child: _buildNutrientItem(
                              context,
                              item,
                              isLeft: true,
                              maxGaugeWidth: maxGaugeWidth,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

                // [중앙 간격]
                SizedBox(width: gap),

                // [오른쪽 열]
                Expanded(
                  // 340px 안에서의 절반 차지
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 최소 크기만 차지
                    crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽(중앙)으로 붙이기
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 위아래 간격 균등 분배
                    children: rightItems
                        .map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: ResponsiveHelper.height(context, 0.005)), // 간격 줄이기
                            child: _buildNutrientItem(
                              context,
                              item,
                              isLeft: false,
                              maxGaugeWidth: maxGaugeWidth,
                            ),
                          ),
                        )
                        .toList(),
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

    // 텍스트 너비 설정 - 텍스트가 잘리지 않도록 더 넉넉하게
    final labelWidth = ResponsiveHelper.width(context, isLeft ? 0.08 : 0.12);
    // 텍스트와 바 사이 간격
    final spacing = ResponsiveHelper.width(context, 0.008);

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
              fontSize: ResponsiveHelper.fontSize(context, 11),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF000000),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 텍스트와 바 사이 간격
        SizedBox(width: spacing),

        // 2. 게이지 바 - 고정 너비로 설정하여 6개 모두 같은 길이 보장
        SizedBox(
          width: maxGaugeWidth, // 모든 게이지 바가 동일한 최대 너비 사용
          height: ResponsiveHelper.height(context, 0.038),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ResponsiveHelper.height(context, 0.033)),
            child: Stack(
              children: [
                // 빈 게이지 배경
                Container(
                  width: double.infinity,
                  height: ResponsiveHelper.height(context, 0.038),
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
      ],
    );
  }
}
