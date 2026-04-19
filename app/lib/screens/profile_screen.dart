import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/top_app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignaScaffold(
      currentRoute: '/profile',
      child: Column(
        children: [
          const SignaAppBar(title: 'Profile'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowTint(opacity: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('S',
                              style: GoogleFonts.manrope(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryContainer)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Sarah M.',
                          style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface)),
                      Text('sarah.m@signa.health',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.outline)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _Section(title: 'CLINICAL', tiles: [
                  _SettingTile(
                    icon: Icons.medical_services_outlined,
                    title: 'Linked Clinician',
                    subtitle: 'Prof. Dr. S. Moritz',
                    onTap: () {},
                  ),
                  _SettingTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Alerts',
                    subtitle: 'Score < 0.50 → clinician',
                    onTap: () {},
                  ),
                  _SettingTile(
                    icon: Icons.assignment_outlined,
                    title: 'PHQ-9 Log',
                    subtitle: 'Optional weekly questionnaire',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 20),
                _Section(title: 'DEVICES & DATA', tiles: [
                  _SettingTile(
                    icon: Icons.sync_alt_rounded,
                    title: 'Connected Devices',
                    subtitle: 'Apple Watch · Manage',
                    onTap: () => context.go('/connect'),
                  ),
                  _SettingTile(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'On-device processing · PHIPA',
                    onTap: () {},
                  ),
                  _SettingTile(
                    icon: Icons.file_download_outlined,
                    title: 'Export Data',
                    subtitle: 'CSV · JSON',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 20),
                _Section(title: 'APP', tiles: [
                  _SettingTile(
                    icon: Icons.info_outline,
                    title: 'About Signa',
                    subtitle: 'v1.0.0',
                    onTap: () {},
                  ),
                  _SettingTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    onTap: () => context.go('/'),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> tiles;
  const _Section({required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Text(title,
              style: AppTheme.labelUppercase(
                  color: AppColors.primaryContainer, size: 11)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: AppColors.primaryContainer, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
