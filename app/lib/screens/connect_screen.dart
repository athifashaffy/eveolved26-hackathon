import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/healthkit_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/top_app_bar.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _healthKitConnected = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await HealthKitService.instance.hasPermission();
    if (!mounted) return;
    setState(() => _healthKitConnected = has);
  }

  Future<void> _connectHealthKit() async {
    setState(() => _checking = true);
    final ok = await HealthKitService.instance.requestAuthorization();
    if (!mounted) return;
    setState(() {
      _healthKitConnected = ok;
      _checking = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'HealthKit not authorized. Enable in Settings → Privacy → Health.'),
        ),
      );
    }
  }

  void _connectFitbit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitbit OAuth flow — configured post-auth milestone.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignaScaffold(
      currentRoute: '/connect',
      child: Column(
        children: [
          SignaAppBar(
            title: 'Connected Devices',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Text('ACTIVE DEVICE',
                    style: AppTheme.labelUppercase(
                        color: AppColors.primaryContainer, size: 12)),
                const SizedBox(height: 12),
                _ActiveDeviceCard(
                  connected: _healthKitConnected,
                  checking: _checking,
                  onSync: _connectHealthKit,
                ),
                const SizedBox(height: 28),
                Text('ADD DEVICE',
                    style: AppTheme.labelUppercase(
                        color: AppColors.primaryContainer, size: 12)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _AddDeviceTile(
                      icon: Icons.watch_rounded,
                      label: 'Apple Watch',
                      accent: _healthKitConnected,
                      onTap: _connectHealthKit,
                    ),
                    _AddDeviceTile(
                      icon: Icons.favorite_rounded,
                      label: 'Fitbit',
                      onTap: _connectFitbit,
                    ),
                    _AddDeviceTile(
                      icon: Icons.radio_button_checked,
                      label: 'Oura Ring',
                      onTap: () {},
                    ),
                    _AddDeviceTile(
                      icon: Icons.explore_rounded,
                      label: 'Garmin',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AddDeviceTile(
                  icon: Icons.edit_note,
                  label: 'Manual Data Entry',
                  full: true,
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                _PrivacyCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveDeviceCard extends StatelessWidget {
  final bool connected;
  final bool checking;
  final VoidCallback onSync;
  const _ActiveDeviceCard({
    required this.connected,
    required this.checking,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint(opacity: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.watch,
                    color: AppColors.primaryContainer, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Apple Watch',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: connected
                                ? Colors.green.shade100
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            connected ? 'CONNECTED' : 'NOT CONNECTED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: connected
                                  ? Colors.green.shade800
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? 'Reading via HealthKit' : 'Tap to authorize',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _DataChip(label: 'HRV', active: connected),
              const SizedBox(width: 8),
              _DataChip(label: 'Sleep', active: connected),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: checking ? null : onSync,
              child: Text(checking
                  ? 'Requesting…'
                  : connected
                      ? 'Sync Now'
                      : 'Authorize HealthKit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;
  final bool active;
  const _DataChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color =
        active ? Colors.green.shade700 : AppColors.onSurfaceVariant;
    final bg = active ? Colors.green.shade50 : AppColors.surfaceContainerLow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _AddDeviceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool full;
  final bool accent;
  const _AddDeviceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.full = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: full
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon,
                  color: accent
                      ? AppColors.primaryContainer
                      : AppColors.onSurface,
                  size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('PRIVACY FIRST',
                  style: AppTheme.labelUppercase(
                      color: AppColors.primary, size: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Signa processes data on-device. No raw physiological data leaves your phone. PHIPA compliant.',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSecondaryContainer,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
