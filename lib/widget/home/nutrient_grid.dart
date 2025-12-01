import 'package:flutter/material.dart';

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // [왼쪽 열]
        Column(
          // [핵심 1] 컬럼 내부 아이템들을 '좌측(Start)'으로 정렬
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // 위아래 간격 균등 분배
          children: leftItems.map((item) => _buildNutrientItem(item, isLeft: true)).toList(),
        ),

        // [간격]
        const SizedBox(width: 8),

        // [오른쪽 열]
        Column(
          // [핵심 1] 컬럼 내부 아이템들을 '좌측(Start)'으로 정렬
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rightItems.map((item) => _buildNutrientItem(item, isLeft: false)).toList(),
        ),
      ],
    );
  }

  Widget _buildNutrientItem(Map<String, dynamic> item, {required bool isLeft}) {
    final label = item['label'] as String;
    final progress = (item['progress'] as num? ?? 0).toDouble();
    final clampedProgress = progress.clamp(0.0, 100.0);

    // 텍스트 너비 설정 (왼쪽 줄 30, 오른쪽 줄 50)
    final labelWidth = isLeft ? 30.0 : 50.0;

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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF000000),
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),

        // 텍스트와 바 사이 간격 (0으로 설정)
        const SizedBox(width: 5),

        // 2. 게이지 바 (크기 고정)
        SizedBox(
          width: 55,
          height: 30,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              if (clampedProgress > 0)
                FractionallySizedBox(
                  widthFactor: clampedProgress / 100.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFEF493),
                          Color(0xFFD2ECBF),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
