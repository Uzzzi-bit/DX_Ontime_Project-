import 'package:flutter/material.dart';

class BottomBarWidget extends StatelessWidget {
  const BottomBarWidget({super.key, required this.currentRoute});

  final String currentRoute;

  void _navigateTo(BuildContext context, String route) {
    if (currentRoute == route) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              _NavItem(
                icon: Icons.home,
                active: currentRoute == '/',
                onTap: () => _navigateTo(context, '/'),
              ),
              Text('홈'),
            ],
          ),

          Column(
            children: [
              _NavItem(
                icon: Icons.widgets_outlined,
                active: currentRoute == '/chat',
                onTap: () => _navigateTo(context, '/chat'),
              ),
              Text('디바이스'),
            ],
          ),

          Column(
            children: [
              _NavItem(
                icon: Icons.other_houses_outlined,
                active: currentRoute == '/report',
                onTap: () => _navigateTo(context, '/report'),
              ),
              Text('케어'),
            ],
          ),

          Column(
            children: [
              _NavItem(
                icon: Icons.list_alt_rounded,
                active: currentRoute == '/settings',
                onTap: () => _navigateTo(context, '/settings'),
              ),
              Text('메뉴'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, this.active = false, this.onTap});

  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2EB5FA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Icon(
                icon,
                color: active ? const Color(0xFF1E1E1E) : const Color(0xFF9A9A9A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
