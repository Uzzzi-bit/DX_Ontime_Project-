import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:intl/intl.dart';
import '../../utils/responsive_helper.dart';

class HeaderSection extends StatelessWidget {
  final String userName;
  final int? pregnancyWeek; // nullable로 변경
  final DateTime? dueDate; // nullable로 변경
  final double? pregnancyProgress; // nullable로 변경
  final VoidCallback onHealthInfoUpdate;

  const HeaderSection({
    super.key,
    required this.userName,
    this.pregnancyWeek, // optional로 변경
    this.dueDate, // optional로 변경
    this.pregnancyProgress, // optional로 변경
    required this.onHealthInfoUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd', 'ko');
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      height: ResponsiveHelper.height(context, 0.37),
      padding: EdgeInsets.fromLTRB(
        ResponsiveHelper.width(context, 0.053),
        ResponsiveHelper.height(context, 0.035),
        ResponsiveHelper.width(context, 0.053),
        ResponsiveHelper.height(context, 0.03),
      ), // 하단 패딩 최소
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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 닉네임 길이에 따라 폰트 크기 동적 조정
                    final nameLength = userName.length;
                    double nameFontSize = 28;
                    double suffixFontSize = 20;

                    // 닉네임이 길면 폰트 크기 조정
                    if (nameLength > 8) {
                      nameFontSize = 24;
                      suffixFontSize = 18;
                    }
                    if (nameLength > 12) {
                      nameFontSize = 20;
                      suffixFontSize = 16;
                    }
                    if (nameLength > 16) {
                      nameFontSize = 18;
                      suffixFontSize = 14;
                    }

                    return RichText(
                      maxLines: null, // 닉네임이 길어도 전체 표시
                      overflow: TextOverflow.visible, // 잘리지 않도록
                      text: TextSpan(
                        style:
                            textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: nameFontSize,
                              letterSpacing: 0.5,
                              color: Colors.black,
                              height: 1.2,
                            ) ??
                            TextStyle(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Colors.black,
                              height: 1.2,
                            ),
                        children: [
                          TextSpan(text: userName),
                          TextSpan(
                            text: '님 홈',
                            style: TextStyle(
                              fontSize: suffixFontSize,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Bounceable(
                onTap: () {},
                child: TextButton(
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
              ),
            ],
          ),
          // 건강정보가 있을 때만 임신주차, 게이지바, 출산예정일 표시
          if (pregnancyWeek != null && dueDate != null && pregnancyProgress != null) ...[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          final progressWidth = barWidth * pregnancyProgress!.clamp(0.0, 1.0);
                          return SizedBox(
                            height: 10,
                            child: Stack(
                              children: [
                                // 배경 바 (회색)
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
                                // 진행 바 (진한 하늘색)
                                Positioned(
                                  top: 3,
                                  left: 0,
                                  child: Container(
                                    width: progressWidth,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3A8FA8), // 진한 하늘색
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                ),
                                // 구분선 점들
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(dueDate!),
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
        ],
      ),
    );
  }
}
