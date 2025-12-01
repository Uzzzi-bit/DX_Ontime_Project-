import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HeaderSection extends StatelessWidget {
  final String userName;
  final int pregnancyWeek;
  final DateTime dueDate;
  final double pregnancyProgress;
  final VoidCallback onHealthInfoUpdate;

  const HeaderSection({
    super.key,
    required this.userName,
    required this.pregnancyWeek,
    required this.dueDate,
    required this.pregnancyProgress,
    required this.onHealthInfoUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd', 'ko');
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24), // 하단 패딩 최소
      decoration: const BoxDecoration(
        color: Color(0xFFBCE7F0),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style:
                        textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 28,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ) ??
                        const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                    children: [
                      TextSpan(text: userName),
                      TextSpan(
                        text: '님 홈',
                        style: TextStyle(
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onHealthInfoUpdate,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: const Color(0xFF5BB5C8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '건강정보 업데이트',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth - 72 - 8 - 61;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '임신 $pregnancyWeek 주차',
                    style:
                        textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ) ??
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 3,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 3,
                            left: 0,
                            child: FractionallySizedBox(
                              widthFactor: pregnancyProgress.clamp(0.0, 1.0),
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A8FA8), // 진한 하늘색
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                            ),
                          ),
                          ...List.generate(4, (index) {
                            final position = index / 3;
                            return Positioned(
                              left: position * barWidth,
                              top: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFF0ECE4),
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(dueDate),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
