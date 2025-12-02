import 'package:flutter/material.dart';

class SupplementChecklist extends StatelessWidget {
  const SupplementChecklist({
    super.key,
    required this.supplements,
    required this.selectedSupplements,
    required this.onToggle,
    required this.onAdd,
  });

  final List<String> supplements;
  final Set<String> selectedSupplements;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '영양제 체크리스트',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.14,
                color: Color(0xFF0F0F0F),
              ),
            ),
            InkWell(
              onTap: onAdd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '영양제 추가하기',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.09,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 13,
                    height: 13,
                    decoration: const BoxDecoration(
                      color: Color(0xFFBCE7F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                          color: Color(0xFF0F0F0F),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFF0ECE4)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final containerWidth = constraints.maxWidth;
              final padding = 16.0 * 2; // 좌우 패딩
              final spacing = 16.0 * 2; // 아이템 간 간격 (3개 아이템이므로 2개 간격)
              final itemWidth = (containerWidth - padding - spacing) / 3;

              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: supplements.map((supplement) {
                  final isSelected = selectedSupplements.contains(supplement);

                  return SizedBox(
                    width: itemWidth,
                    child: InkWell(
                      onTap: () => onToggle(supplement),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (_) => onToggle(supplement),
                              activeColor: const Color(0xFF5BB5C8),
                              side: const BorderSide(
                                color: Color(0x26000000),
                                width: 1,
                              ),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              supplement,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0.11,
                                color: Color(0xFF0F0F0F),
                              ),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
