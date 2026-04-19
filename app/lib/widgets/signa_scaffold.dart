import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  final String route;
  const BottomNavItem(this.icon, this.label, this.route);
}

const _items = [
  BottomNavItem(Icons.home_rounded, 'Home', '/home'),
  BottomNavItem(Icons.insights_rounded, 'Trends', '/trends'),
  BottomNavItem(Icons.sync_alt_rounded, 'Connect', '/connect'),
  BottomNavItem(Icons.person_rounded, 'Profile', '/profile'),
];

class SignaScaffold extends StatelessWidget {
  final String currentRoute;
  final Widget child;
  final bool showNav;
  const SignaScaffold({
    super.key,
    required this.currentRoute,
    required this.child,
    this.showNav = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      body: child,
      bottomNavigationBar: showNav ? _buildBottomNav(context) : null,
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
          top: 12, bottom: 24 + MediaQuery.of(context).padding.bottom * 0, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _items.map((it) {
          final active = currentRoute.startsWith(it.route);
          return Expanded(child: _NavItem(item: it, active: active));
        }).toList(),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final BottomNavItem item;
  final bool active;
  const _NavItem({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.route),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryContainer.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 24,
              color: active ? AppColors.primaryContainer : AppColors.outline,
            ),
            const SizedBox(height: 4),
            Text(
              item.label.toUpperCase(),
              style: AppTheme.labelUppercase(
                color: active ? AppColors.primaryContainer : AppColors.outline,
                size: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
