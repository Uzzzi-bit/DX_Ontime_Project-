import 'package:flutter/material.dart';
import '../theme/color_palette.dart';
import '../widget/bottom_bar_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _primaryText = ColorPalette.textPrimary;
  static const _secondaryText = ColorPalette.textSecondary;
  static const _surface = ColorPalette.surface;
  static const _background = ColorPalette.background;
  static const _surfaceVariant = ColorPalette.primary300;
  static final _outline = ColorPalette.bg300.withOpacity(0.8);

  static const _manageSection = MenuSection(
    title: '제품 사용과 관리',
    items: [
      MenuItem(
        title: '스마트 진단',
        subtitle: '제품 상태를 원격 점검',
        icon: Icons.biotech_outlined,
      ),
      MenuItem(
        title: '제품 정보와 보증',
        subtitle: '보증 기간과 시리얼',
        icon: Icons.assignment_outlined,
      ),
      MenuItem(
        title: '제품 사용설명서',
        subtitle: 'PDF 매뉴얼 내려받기',
        icon: Icons.menu_book_outlined,
      ),
      MenuItem(
        title: 'LG전자 구독',
        subtitle: '프리미엄 케어 서비스',
        icon: Icons.subscriptions_outlined,
      ),
    ],
  );

  static const _appSection = MenuSection(
    title: '제품 및 앱 활용',
    items: [
      MenuItem(
        title: 'ThinQ PLAY',
        subtitle: '추천 액션과 콘텐츠',
        icon: Icons.play_circle_outline,
      ),
      MenuItem(
        title: '스마트 루틴',
        subtitle: '자주 쓰는 자동화 만들기',
        icon: Icons.auto_mode_outlined,
      ),
      MenuItem(
        title: 'ThinQ 활용하기',
        subtitle: '활용 가이드 모음',
        icon: Icons.tips_and_updates_outlined,
      ),
      MenuItem(
        title: '임산부 모드',
        subtitle: '연결된 디바이스 동기화',
        icon: Icons.child_friendly_outlined,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
          icon: const Icon(Icons.keyboard_backspace),
        ),
        title: Text(
          '설정',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildSegmentedControl(),
              const SizedBox(height: 24),
              _buildPromoCard(),
              const SizedBox(height: 32),
              const _MenuSectionWidget(section: _manageSection),
              const SizedBox(height: 32),
              const _MenuSectionWidget(section: _appSection),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/settings'),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LG ThinQ',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '고객 지원',
              style: textTheme.titleMedium?.copyWith(color: _secondaryText),
            ),
          ],
        ),
        Row(
          children: [
            _HeaderIcon(
              icon: Icons.notifications_outlined,
              background: _surfaceVariant,
            ),
            const SizedBox(width: 16),
            _HeaderIcon(
              icon: Icons.settings_outlined,
              background: _surfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorPalette.bg300),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _outline),
              ),
              alignment: Alignment.center,
              child: Text(
                '마이페이지',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _secondaryText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _outline),
              ),
              alignment: Alignment.center,
              child: const Text(
                '고객 지원',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorPalette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _PromoIcon(
            icon: Icons.local_offer_outlined,
            background: _surface.withOpacity(0.4),
          ),
          const SizedBox(width: 12),
          _PromoIcon(
            icon: Icons.shield_outlined,
            background: _surface.withOpacity(0.4),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '시크릿 쿠폰 프로모션',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.background});

  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: ColorPalette.textPrimary),
    );
  }
}

class _PromoIcon extends StatelessWidget {
  const _PromoIcon({required this.icon, required this.background});

  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: ColorPalette.textPrimary),
    );
  }
}

class MenuSection {
  const MenuSection({required this.title, required this.items});

  final String title;
  final List<MenuItem> items;
}

class MenuItem {
  const MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _MenuSectionWidget extends StatelessWidget {
  const _MenuSectionWidget({required this.section});

  final MenuSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: theme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: ColorPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ColorPalette.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              for (var i = 0; i < section.items.length; i++) ...[
                _MenuItemTile(item: section.items[i]),
                if (i != section.items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 28,
                      color: ColorPalette.bg300,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorPalette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: ColorPalette.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: theme.bodySmall?.copyWith(
                    color: ColorPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: ColorPalette.textSecondary),
        ],
      ),
    );
  }
}
