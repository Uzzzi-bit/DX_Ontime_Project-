import 'package:flutter/material.dart';
import '../theme/color_palette.dart';
import '../widget/bottom_bar_widget.dart';

class AddFamilyScreen extends StatefulWidget {
  const AddFamilyScreen({super.key});

  @override
  State<AddFamilyScreen> createState() => _AddFamilyScreenState();
}

class _AddFamilyScreenState extends State<AddFamilyScreen> {
  final List<_FamilyMember> _members = [
    const _FamilyMember(
      id: 'partner',
      relation: '배우자',
      name: '남편',
      description: '긴급 알림을 가장 먼저 전달할 케어 메이트입니다.',
    ),
    const _FamilyMember(
      id: 'mother',
      relation: '부모님',
      name: '엄마',
      description: '기본 건강 리포트를 자동 공유해요.',
    ),
    const _FamilyMember(
      id: 'father',
      relation: '부모님',
      name: '아빠',
      description: '투약 알림 연동 시 알림을 함께 받습니다.',
    ),
    const _FamilyMember(
      id: 'aunt',
      relation: '가족',
      name: '이모',
      description: '케어 기록 열람만 가능한 뷰어 권한입니다.',
    ),
    const _FamilyMember(
      id: 'sibling',
      relation: '형제자매',
      name: '언니',
      description: '주간 리포트를 이메일로 받아요.',
    ),
    const _FamilyMember(
      id: 'friend',
      relation: '지인',
      name: '친구',
      description: '긴급 상황 시 문자 알림만 전송됩니다.',
    ),
  ];

  final Set<String> _selectedIds = {'partner', 'father'};
  void _handleSubmit() {
    Navigator.pop(context, true);
  }

  void _toggleSelection(String memberId) {
    setState(() {
      if (_selectedIds.contains(memberId)) {
        _selectedIds.remove(memberId);
      } else {
        _selectedIds.add(memberId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
          icon: Icon(Icons.keyboard_backspace, color: colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '가족 구성원 추가',
                style:
                    theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ) ??
                    const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: ColorPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '가족 구성원을 추가하세요.\n필요 시 알람이 전송 됩니다.\n(복수 선택 가능)',
                style:
                    theme.textTheme.titleMedium?.copyWith(
                      height: 1.3,
                      color: colorScheme.onSurface,
                    ) ??
                    const TextStyle(
                      fontSize: 20,
                      height: 1.3,
                      color: ColorPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isSelected = _selectedIds.contains(member.id);
                    return _FamilyMemberTile(
                      member: member,
                      isSelected: isSelected,
                      onChanged: () => _toggleSelection(member.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _handleSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedIds.isEmpty ? '구성원을 선택해 주세요' : '${_selectedIds.length}명 추가하기',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/addfamily'),
    );
  }
}

class _FamilyMemberTile extends StatelessWidget {
  const _FamilyMemberTile({
    required this.member,
    required this.isSelected,
    required this.onChanged,
  });

  final _FamilyMember member;
  final bool isSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Monogram(initial: member.name.characters.first),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.relation,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: ColorPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: ColorPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    member.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: ColorPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                if (member.trailingLabel != null)
                  Text(
                    member.trailingLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: ColorPalette.textSecondary,
                    ),
                  ),
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onChanged(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  activeColor: colorScheme.primary,
                  side: const BorderSide(color: ColorPalette.textSecondary, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: ColorPalette.primary100.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ColorPalette.primary300,
        ),
      ),
    );
  }
}

class _FamilyMember {
  const _FamilyMember({
    required this.id,
    required this.relation,
    required this.name,
    required this.description,
    this.trailingLabel,
  });

  final String id;
  final String relation;
  final String name;
  final String description;
  final String? trailingLabel;
}
