import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/top_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignaScaffold(
      currentRoute: '/profile',
      showNav: false,
      child: Column(
        children: [
          SignaAppBar(
            title: 'Privacy Policy',
            showAvatar: false,
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/profile'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: const [
                _Updated('Last updated: June 23, 2026'),
                _Para(
                  'Signa is designed privacy-first. Your health data is '
                  'processed and stored only on this device. We do not run a '
                  'server and we never upload your data anywhere automatically.',
                ),
                _Heading('On-device only'),
                _Para(
                  'All analysis — including your Stability Score — is computed '
                  'locally on your phone. Nothing leaves the device unless you '
                  'choose to export and share it.',
                ),
                _Heading('What we store'),
                _Para(
                  'Heart rate variability (HRV), sleep, steps, your computed '
                  'stability scores, your daily check-ins (sleep and mood '
                  'self-reports), and the profile details you enter (name, date '
                  'of birth, email, linked clinician).',
                ),
                _Heading('Where data comes from'),
                _Para(
                  'Data is read from Apple Health or Fitbit only after you '
                  'explicitly authorize access. You can revoke access at any '
                  'time in your device or Fitbit account settings.',
                ),
                _Heading('Sharing your data'),
                _Para(
                  'Exports (CSV or JSON) are created only when you tap "Share My '
                  'Data". You choose who receives the file — for example, you '
                  'can show or send it to your physician. Once shared, the '
                  'recipient controls that copy.',
                ),
                _Heading('Deleting your data'),
                _Para(
                  'Uninstalling Signa removes all locally stored data from this '
                  'device, including readings, check-ins, and your profile.',
                ),
                _Heading('Not a medical device'),
                _Para(
                  'Signa is for informational and self-monitoring purposes only. '
                  'It does not diagnose, treat, or prevent any condition. Always '
                  'consult a qualified clinician about your health.',
                ),
                _Heading('Your rights'),
                _Para(
                  'Signa is built to align with PIPEDA and PHIPA principles '
                  '(Canada) and privacy-by-design: data minimization, on-device '
                  'processing, and user-controlled sharing.',
                ),
                _Heading('Contact'),
                _Para(
                  'Questions about privacy? Reach the Signa team via the '
                  'Evolved26 Hackathon project channel.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(text,
            style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
      );
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 14, height: 1.5, color: AppColors.onSurfaceVariant));
}

class _Updated extends StatelessWidget {
  final String text;
  const _Updated(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline)),
      );
}
