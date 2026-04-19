import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/top_app_bar.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SignaAppBar(
            title: 'Transition Warning',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                color: AppColors.error, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Text('Stability transition detected',
                              style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onErrorContainer)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your HRV × Sleep interaction score dropped below the clinical threshold (0.50) for 3 consecutive days.',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onErrorContainer,
                            height: 1.55),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _kv('Current score', '0.41'),
                            const SizedBox(height: 8),
                            _kv('7-day average', '0.55'),
                            const SizedBox(height: 8),
                            _kv('Clinician notified', 'Mar 15, 9:42 AM'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('WHAT MAY HELP',
                    style: AppTheme.labelUppercase(
                        color: AppColors.primaryContainer, size: 12)),
                const SizedBox(height: 12),
                _SuggestionTile(
                  icon: Icons.bedtime_outlined,
                  title: 'Protect sleep consistency',
                  body:
                      'Your recent sleep variance is 1.8× baseline. Aim for a regular bedtime window over the next 3 nights.',
                ),
                const SizedBox(height: 10),
                _SuggestionTile(
                  icon: Icons.self_improvement,
                  title: 'Slow-breath practice',
                  body:
                      '5 minutes of paced breathing (6 breaths/min) can raise daytime HRV over several days.',
                ),
                const SizedBox(height: 10),
                _SuggestionTile(
                  icon: Icons.medical_services_outlined,
                  title: 'Contact your clinician',
                  body:
                      'Prof. Moritz was notified automatically. You can also message them directly.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Acknowledge & Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.onSurfaceVariant)),
        Text(v,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
