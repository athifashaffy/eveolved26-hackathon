import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_settings.dart';
import '../data/fitbit_service.dart';
import '../data/healthkit_service.dart';
import '../data/real_data.dart';
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
  bool _fitbitConnected = false;
  bool _checking = false;

  String? get _activeSource => AppSettings.instance.activeSource;
  bool get _fitbitIsActive =>
      _fitbitConnected && _activeSource == AppSettings.sourceFitbit;
  bool get _appleIsActive =>
      _healthKitConnected && _activeSource == AppSettings.sourceAppleHealth;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final hk = await HealthKitService.instance.hasPermission();
    final fb = await FitbitService.instance.isAuthenticated();
    if (!mounted) return;
    setState(() {
      _healthKitConnected = hk;
      _fitbitConnected = fb;
    });
  }

  Future<void> _connectHealthKit() async {
    if (_healthKitConnected) {
      if (!_appleIsActive) {
        await _setActive(AppSettings.sourceAppleHealth);
      } else {
        await _showAppleDisconnectInfo();
      }
      return;
    }

    setState(() => _checking = true);
    final ok = await HealthKitService.instance.requestAuthorization();
    if (!mounted) return;
    setState(() {
      _healthKitConnected = ok;
      _checking = false;
    });
    if (ok) {
      await RealData.onDeviceConnected(AppSettings.sourceAppleHealth);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple Health connected — syncing data…')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'HealthKit not authorized. Enable in Settings → Privacy → Health.'),
        ),
      );
    }
  }

  Future<void> _connectFitbit() async {
    if (_fitbitConnected) {
      if (!_fitbitIsActive) {
        await _setActive(AppSettings.sourceFitbit);
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Disconnect Fitbit?'),
          content: const Text(
              'Your Fitbit account will be unlinked. If Apple Health is also connected, the app will switch to it.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disconnect')),
          ],
        ),
      );
      if (confirm == true) {
        await FitbitService.instance.logout();
        await RealData.onDeviceDisconnected(AppSettings.sourceFitbit);
        if (mounted) setState(() => _fitbitConnected = false);
      }
      return;
    }

    setState(() => _checking = true);
    final ok = await FitbitService.instance.authenticate();
    if (!mounted) return;

    if (ok) {
      await RealData.onDeviceConnected(AppSettings.sourceFitbit);
      setState(() {
        _fitbitConnected = true;
        _checking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitbit connected — syncing data…')),
      );
    } else {
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitbit connection failed. Try again.')),
      );
    }
  }

  Future<void> _setActive(String source) async {
    await RealData.setActiveSource(source);
    if (!mounted) return;
    setState(() {});
    final label =
        source == AppSettings.sourceFitbit ? 'Fitbit' : 'Apple Health';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is now the active data source')),
    );
  }

  Future<void> _showAppleDisconnectInfo() async {
    final forget = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect Apple Health'),
        content: const Text(
          'Apple Health permissions live in iOS Settings → Privacy & Security → Health → Signa. '
          'You can also stop Signa from using Apple Health on this device — your iOS authorization stays intact and you can reconnect later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget on this device'),
          ),
        ],
      ),
    );
    if (forget == true) {
      await HealthKitService.instance.forgetAuthorization();
      await RealData.onDeviceDisconnected(AppSettings.sourceAppleHealth);
      if (mounted) setState(() => _healthKitConnected = false);
    }
  }

  Future<void> _activeCardAction() async {
    final hasActive =
        _activeSource != null && (_fitbitIsActive || _appleIsActive);
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing from device…')),
      );
      await RealData.forceSync();
      return;
    }
    if (_fitbitConnected) {
      await _connectFitbit();
    } else {
      await _connectHealthKit();
    }
  }

  String get _activeDeviceName {
    if (_fitbitIsActive) return 'Fitbit';
    if (_appleIsActive) return 'Apple Health';
    if (_fitbitConnected) return 'Fitbit';
    if (_healthKitConnected) return 'Apple Health';
    return 'Apple Watch';
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _fitbitIsActive || _appleIsActive;
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
                  connected: hasActive,
                  deviceName: _activeDeviceName,
                  checking: _checking,
                  onSync: _activeCardAction,
                ),
                const SizedBox(height: 28),
                Text('ADD DEVICE',
                    style: AppTheme.labelUppercase(
                        color: AppColors.primaryContainer, size: 12)),
                const SizedBox(height: 12),
                if (_fitbitConnected && _healthKitConnected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Tap a connected device to switch which one feeds your stability score.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ),
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
                      active: _appleIsActive,
                      onTap: _connectHealthKit,
                    ),
                    _AddDeviceTile(
                      icon: Icons.favorite_rounded,
                      label: 'Fitbit',
                      accent: _fitbitConnected,
                      active: _fitbitIsActive,
                      onTap: _checking ? () {} : _connectFitbit,
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
  final String deviceName;
  final VoidCallback onSync;
  const _ActiveDeviceCard({
    required this.connected,
    required this.checking,
    required this.deviceName,
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
                            deviceName,
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
                      connected ? 'Tap below to sync now' : 'Tap to authorize',
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
              const SizedBox(width: 8),
              _DataChip(label: 'Steps', active: connected),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: checking ? null : onSync,
              child: Text(checking
                  ? 'Connecting…'
                  : connected
                      ? 'Sync Now'
                      : 'Connect Device'),
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
    final color = active ? Colors.green.shade700 : AppColors.onSurfaceVariant;
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
  final bool active;
  const _AddDeviceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.full = false,
    this.accent = false,
    this.active = false,
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
          border: active
              ? Border.all(color: AppColors.primaryContainer, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  full ? CrossAxisAlignment.center : CrossAxisAlignment.center,
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
            if (active)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
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
