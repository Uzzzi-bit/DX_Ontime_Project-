import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/color_palette.dart';
import '../widget/bottom_bar_widget.dart';
import '../api/member_api_service.dart';

class MomCareSettingScreen extends StatefulWidget {
  const MomCareSettingScreen({super.key});

  @override
  State<MomCareSettingScreen> createState() => _MomCareSettingScreenState();
}

class _MomCareSettingScreenState extends State<MomCareSettingScreen> {
  bool _isMomCareOn = false;
  static const String _momCareModeKey = 'isMomCareMode';

  @override
  void initState() {
    super.initState();
    _loadMomCareMode();
  }

  Future<void> _loadMomCareMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMomCareOn = prefs.getBool(_momCareModeKey) ?? false;
    });
  }

  Future<void> _saveMomCareMode(bool value) async {
    // 1) SharedPreferences에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_momCareModeKey, value);

    // 2) Django 서버에 is_pregnant_mode 업데이트
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await MemberApiService.instance.updatePregnantMode(user.uid, value);
        debugPrint('is_pregnant_mode 업데이트 성공: $value');
      }
    } catch (e) {
      debugPrint('is_pregnant_mode 업데이트 실패: $e');
      // 오류가 발생해도 SharedPreferences는 저장되었으므로 사용자에게 알림만 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서버 업데이트 실패: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  static const _primaryText = ColorPalette.textPrimary;
  static const _secondaryText = ColorPalette.textSecondary;
  static const _surface = ColorPalette.surface;
  static const _background = ColorPalette.background;
  static const _accent = ColorPalette.primary300;

  final List<_MomCareMenuItem> _menuItems = const [
    _MomCareMenuItem(
      title: '건강 정보 입력',
      subtitle: '개인 건강 정보를 통해 개인 맞춤 솔루션을 제공합니다.',
      icon: Icons.edit_square,
      route: '/healthinfo',
    ),
    _MomCareMenuItem(
      title: '가족 구성원 추가',
      subtitle: '추가된 가족 구성원에게 필요 시 알람이 전송됩니다.',
      icon: Icons.people_outline_rounded,
      route: '/addfamily',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
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
          '맘케어 모드',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(context),
              const SizedBox(height: 24),
              AnimatedCrossFade(
                firstChild: _ModeOffPlaceholder(
                  headline: '맘케어 모드를 켜 주세요',
                  description: 'OFF 상태에서는 맞춤 메뉴가 제공되지 않습니다.',
                ),
                secondChild: _MomCareMenuList(items: _menuItems),
                crossFadeState: _isMomCareOn ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomBarWidget(currentRoute: '/momcaresetting'),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isMomCareOn ? _accent : ColorPalette.bg300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isMomCareOn ? 'Mom Care On' : 'Mom Care Off',
                    style: theme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isMomCareOn ? '맞춤 케어 메뉴가 활성화되었습니다.' : '스위치를 켜면 맞춤 메뉴가 나타납니다.',
                    style: theme.bodySmall?.copyWith(color: _secondaryText),
                  ),
                ],
              ),
              Switch(
                value: _isMomCareOn,
                activeColor: _surface,
                activeTrackColor: _accent,
                onChanged: (value) async {
                  setState(() => _isMomCareOn = value);
                  await _saveMomCareMode(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorPalette.primary300.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.child_friendly_outlined,
                  color: ColorPalette.primary300,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '엄마를 위한 케어,\nLG ThinQ를 Mom Care 모드로 전환합니다.',
                    style: theme.bodyMedium?.copyWith(
                      color: _primaryText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOffPlaceholder extends StatelessWidget {
  const _ModeOffPlaceholder({
    required this.headline,
    required this.description,
  });

  final String headline;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorPalette.bg300),
      ),
      child: Column(
        children: [
          Icon(Icons.visibility_off_outlined, size: 48, color: ColorPalette.textSecondary),
          const SizedBox(height: 16),
          Text(
            headline,
            style: theme.titleMedium?.copyWith(
              color: ColorPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(
              color: ColorPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MomCareMenuList extends StatelessWidget {
  const _MomCareMenuList({required this.items});

  final List<_MomCareMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MomCareMenuTile(item: items[i]),
            if (i != items.length - 1)
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
    );
  }
}

class _MomCareMenuTile extends StatelessWidget {
  const _MomCareMenuTile({required this.item});

  final _MomCareMenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.route == null
            ? null
            : () {
                Navigator.pushNamed(context, item.route!);
              },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorPalette.primary300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: ColorPalette.primary),
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
        ),
      ),
    );
  }
}

class _MomCareMenuItem {
  const _MomCareMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
}
