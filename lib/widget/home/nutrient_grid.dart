import 'package:flutter/material.dart';

class NutrientGrid extends StatelessWidget {
  const NutrientGrid({
    super.key,
    required this.nutrients,
  });

  final List<Map<String, dynamic>> nutrients;

  @override
  Widget build(BuildContext context) {
    // 1. 데이터를 왼쪽 줄(철분, 엽산, 칼슘)과 오른쪽 줄(비타민, 오메가, 콜린)로 분리
    final leftItems = <Map<String, dynamic>>[];
    final rightItems = <Map<String, dynamic>>[];

    for (int i = 0; i < nutrients.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(nutrients[i]); // 0, 2, 4번째 인덱스
      } else {
        rightItems.add(nutrients[i]); // 1, 3, 5번째 인덱스
      }
    }

    // GridView 대신 Row를 사용하여 좌우 배치를 직접 제어
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // [왼쪽 열]
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: leftItems.map((item) => _buildNutrientItem(item, isLeft: true)).toList(),
          ),
        ),

        // [핵심] 여기에 있는 숫자를 줄이면 두 줄 사이가 더 가까워집니다!
        const SizedBox(width: 0),

        // [오른쪽 열]
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rightItems.map((item) => _buildNutrientItem(item, isLeft: false)).toList(),
          ),
        ),
      ],
    );
  }

  // 아이템 하나(글자+바)를 만드는 함수
  Widget _buildNutrientItem(Map<String, dynamic> item, {required bool isLeft}) {
    final label = item['label'] as String;
    final progress = (item['progress'] as num? ?? 0).toDouble();
    final clampedProgress = progress.clamp(0.0, 100.0);

    // 보내주신 코드의 로직 적용 (왼쪽 30, 오른쪽 50)
    final labelWidth = isLeft ? 30.0 : 50.0;

    return Row(
      mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 차지하게 설정
      children: [
        // 1. 텍스트 너비
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF000000),
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),

        // 텍스트와 바 사이 간격 (0으로 설정하셨음)
        const SizedBox(width: 0),

        // 2. 바 (설정하신 크기 적용: 55 x 30)
        SizedBox(
          width: 55,
          height: 30,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                // 빈 게이지 배경
                Container(
                  width: 55,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F0F0),
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
                              Color(0xFFD2ECBF),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
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
