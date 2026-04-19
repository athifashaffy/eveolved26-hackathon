import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final StabilityStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = switch (status) {
      StabilityStatus.stable => (
        AppColors.statusStableFg,
        AppColors.statusStableBg,
        'Stable'
      ),
      StabilityStatus.monitoring => (
        AppColors.statusMonitoringFg,
        AppColors.statusMonitoringBg,
        'Monitoring'
      ),
      StabilityStatus.alert => (
        AppColors.statusAlertFg,
        AppColors.statusAlertBg,
        'Alert'
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: fg,
        ),
      ),
    );
  }
}
