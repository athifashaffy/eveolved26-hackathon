import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_info.dart';
import '../data/app_settings.dart';
import '../data/database_service.dart';
import '../data/export_service.dart';
import '../data/fitbit_service.dart';
import '../data/models.dart';
import '../data/real_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/top_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PatientProfile? _patient;
  bool _loading = true;
  bool _todayChecked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await DatabaseService.instance.getPatient();
    final todayReport =
        await DatabaseService.instance.getSelfReportForDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _patient = p;
      _todayChecked = todayReport != null;
      _loading = false;
    });
    // First launch — prompt to set up profile
    if (p == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editProfile());
    }
  }

  Future<void> _editProfile() async {
    final result = await showDialog<PatientProfile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditProfileDialog(current: _patient),
    );
    if (result != null) {
      await DatabaseService.instance.savePatient(result);
      if (mounted) setState(() => _patient = result);
    }
  }

  Future<void> _syncNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing from device…')),
    );
    await RealData.forceSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync complete')),
      );
    }
  }

  Future<void> _openCheckIn() async {
    final result = await showDialog<SelfReport>(
      context: context,
      builder: (_) => const _DailyCheckInDialog(),
    );
    if (result != null) {
      await DatabaseService.instance.upsertSelfReport(result);
      if (!mounted) return;
      setState(() => _todayChecked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in saved')),
      );
    }
  }

  Future<void> _toggleDemoMode(bool value) async {
    await AppSettings.instance.setUseDemoData(value);
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Demo data enabled'
              : 'Demo data disabled — using watch data',
        ),
      ),
    );
    await RealData.forceSync();
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your local data will be kept on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirm == true && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _patient?.name.isNotEmpty == true ? _patient!.name : 'Set up profile';
    final email = _patient?.email ?? '';
    final initials = _patient?.initials ?? '?';

    return SignaScaffold(
      currentRoute: '/profile',
      child: Column(
        children: [
          const SignaAppBar(title: 'Profile'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                // ─── Avatar card ───────────────────────────────────────────
                GestureDetector(
                  onTap: _editProfile,
                  child: Container(
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
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.manrope(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(name,
                            style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface)),
                        if (email.isNotEmpty)
                          Text(email,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.outline)),
                        if (_patient?.dob != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'DOB: ${_patient!.dob}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.outline),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Clinical ──────────────────────────────────────────────
                _Section(title: 'CLINICAL', tiles: [
                  _SettingTile(
                    icon: Icons.medical_services_outlined,
                    title: 'Linked Clinician',
                    subtitle: _patient?.clinician?.isNotEmpty == true
                        ? _patient!.clinician!
                        : 'Tap to add',
                    onTap: _editProfile,
                  ),
                  _SettingTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Alerts',
                    subtitle: 'Score < 0.50 → clinician notified',
                    onTap: () {},
                  ),
                  _SettingTile(
                    icon: Icons.assignment_outlined,
                    title: 'Daily Check-in',
                    subtitle: _todayChecked ? 'Logged today' : 'Not logged yet',
                    onTap: _openCheckIn,
                  ),
                ]),
                const SizedBox(height: 20),

                // ─── Devices & Data ────────────────────────────────────────
                _Section(title: 'DEVICES & DATA', tiles: [
                  _ToggleSettingTile(
                    icon: Icons.science_outlined,
                    title: 'Demo Data',
                    subtitle: AppSettings.instance.useDemoData
                        ? 'Showing bundled sample dataset'
                        : 'Showing data from your watch only',
                    value: AppSettings.instance.useDemoData,
                    onChanged: _toggleDemoMode,
                  ),
                  _SettingTile(
                    icon: Icons.sync_alt_rounded,
                    title: 'Sync Now',
                    subtitle: 'Pull latest from connected device',
                    onTap: _syncNow,
                  ),
                  _SettingTile(
                    icon: Icons.watch_rounded,
                    title: 'Connected Devices',
                    subtitle: 'Manage wearables',
                    onTap: () => context.go('/connect'),
                  ),
                  _SettingTile(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'On-device processing · PHIPA',
                    onTap: () => context.push('/privacy'),
                  ),
                  _SettingTile(
                    icon: Icons.file_download_outlined,
                    title: 'Share My Data',
                    subtitle: DataExportService.lastExportSubtitle(
                      AppSettings.instance.lastExportAt,
                      AppSettings.instance.lastExportFormat,
                    ),
                    onTap: _exportData,
                  ),
                ]),
                const SizedBox(height: 20),

                // ─── App ───────────────────────────────────────────────────
                _Section(title: 'APP', tiles: [
                  _SettingTile(
                    icon: Icons.info_outline,
                    title: 'About Signa',
                    subtitle: '$kAppVersionLabel · Evolved26 Hackathon',
                    onTap: () {},
                  ),
                  _SettingTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    onTap: _signOut,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final rows = await DatabaseService.instance.getAllReadingsRaw();
      final patient = await DatabaseService.instance.getPatient();
      final reports = await DatabaseService.instance.getAllSelfReports();
      final now = DateTime.now();

      String contentFor(String f) => f == 'json'
          ? DataExportService.buildJson(
              patient: patient,
              readings: rows,
              selfReports: reports,
              versionLabel: kAppVersion,
              exportedAt: now,
            )
          : DataExportService.buildCsv(
              patient: patient,
              readings: rows,
              exportedAt: now,
            );

      var fmt = 'json';

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            final content = contentFor(fmt);
            return AlertDialog(
              title: Text('Share My Data',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'json', label: Text('JSON')),
                          ButtonSegment(value: 'csv', label: Text('CSV')),
                        ],
                        selected: {fmt},
                        onSelectionChanged: (s) => setLocal(() => fmt = s.first),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${rows.length} reading${rows.length == 1 ? '' : 's'} · '
                        '${reports.length} check-in${reports.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(content,
                          style: GoogleFonts.robotoMono(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
                Builder(builder: (btnContext) {
                  return FilledButton.icon(
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                    onPressed: () async {
                      final ext = fmt == 'json' ? 'json' : 'csv';
                      final mime =
                          fmt == 'json' ? 'application/json' : 'text/csv';
                      final dir = await getTemporaryDirectory();
                      final stamp = now
                          .toIso8601String()
                          .replaceAll(':', '-')
                          .substring(0, 19);
                      final file =
                          File('${dir.path}/signa_export_$stamp.$ext');
                      await file.writeAsString(content);

                      final box =
                          btnContext.findRenderObject() as RenderBox?;
                      final origin = box != null && box.hasSize
                          ? box.localToGlobal(Offset.zero) & box.size
                          : const Rect.fromLTWH(0, 0, 1, 1);
                      await Share.shareXFiles(
                        [XFile(file.path, mimeType: mime)],
                        subject: 'Signa data export',
                        text:
                            'Signa stability data — ${rows.length} reading${rows.length == 1 ? '' : 's'}',
                        sharePositionOrigin: origin,
                      );

                      await AppSettings.instance.setLastExport(now, fmt);
                      if (mounted) setState(() {});
                    },
                  );
                }),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

// ─── Edit profile dialog ────────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  final PatientProfile? current;
  const _EditProfileDialog({this.current});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _dob;
  late final TextEditingController _email;
  late final TextEditingController _clinician;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _dob = TextEditingController(text: widget.current?.dob ?? '');
    _email = TextEditingController(text: widget.current?.email ?? '');
    _clinician = TextEditingController(text: widget.current?.clinician ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _email.dispose();
    _clinician.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.current == null ? 'Set up your profile' : 'Edit Profile',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.current == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Enter your details to personalise Signa.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
                ),
              ),
            _Field(controller: _name, label: 'Full Name *', hint: 'e.g. Athif Shaffy'),
            const SizedBox(height: 12),
            _Field(controller: _dob, label: 'Date of Birth', hint: 'YYYY-MM-DD'),
            const SizedBox(height: 12),
            _Field(controller: _email, label: 'Email', hint: 'you@example.com'),
            const SizedBox(height: 12),
            _Field(
                controller: _clinician,
                label: 'Clinician / Therapist',
                hint: 'e.g. Dr. Smith'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              PatientProfile(
                name: _name.text.trim(),
                dob: _dob.text.trim().isNotEmpty ? _dob.text.trim() : null,
                email: _email.text.trim().isNotEmpty ? _email.text.trim() : null,
                clinician:
                    _clinician.text.trim().isNotEmpty ? _clinician.text.trim() : null,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _Field(
      {required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── Shared section/tile widgets ────────────────────────────────────────────

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

class _ToggleSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleSettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryContainer, size: 20),
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
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _SettingTile(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryContainer, size: 20),
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

// ─── Daily check-in dialog ──────────────────────────────────────────────────

class _DailyCheckInDialog extends StatefulWidget {
  const _DailyCheckInDialog();

  @override
  State<_DailyCheckInDialog> createState() => _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends State<_DailyCheckInDialog> {
  int _sleep = 3;
  int _mood = 3;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Daily Check-in',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RatingRow(
              label: 'How did you sleep last night?',
              value: _sleep,
              onChanged: (v) => setState(() => _sleep = v),
            ),
            const SizedBox(height: 16),
            _RatingRow(
              label: 'Mood today?',
              value: _mood,
              onChanged: (v) => setState(() => _mood = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final now = DateTime.now();
            Navigator.pop(
              context,
              SelfReport(
                date: DateTime(now.year, now.month, now.day),
                sleepRating: _sleep,
                moodRating: _mood,
                notes: _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
                createdAt: now,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _RatingRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: i == value
                        ? AppColors.primaryContainer
                        : AppColors.primaryContainer.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('$i',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: i == value
                                ? Colors.white
                                : AppColors.primaryContainer)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Very poor',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline)),
            Text('Very good',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline)),
          ],
        ),
      ],
    );
  }
}
