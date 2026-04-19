import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(
                'Signa',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryContainer,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _WatchHero(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Continuous depression monitoring from your wrist or through manual entry.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryContainer,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Advanced physiological markers captured automatically from your device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/connect'),
                  child: const Text("I'm a Patient"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text("I'm a Clinician"),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 12, color: AppColors.outline),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'HEALTH CANADA SAMD CLASS II',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelUppercase(size: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Tonal scaffolding background circles
        FractionallySizedBox(
          widthFactor: 0.9,
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        FractionallySizedBox(
          widthFactor: 0.72,
          heightFactor: 0.72,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowTint(opacity: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                )
              ],
            ),
          ),
        ),
        // Smartwatch silhouette
        Container(
          width: 160,
          height: 210,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Heart rate line
                SizedBox(
                  height: 30,
                  child: CustomPaint(
                    painter: _HrPainter(),
                    size: const Size(double.infinity, 30),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bedtime,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(1),
                    const SizedBox(width: 4),
                    _dot(0.3),
                    const SizedBox(width: 4),
                    _dot(0.3),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(double opacity) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.onPrimaryContainer.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      );
}

class _HrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onPrimaryContainer
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final h = size.height;
    final w = size.width;
    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.2, h * 0.5);
    path.lineTo(w * 0.25, h * 0.25);
    path.lineTo(w * 0.35, h * 0.85);
    path.lineTo(w * 0.4, h * 0.5);
    path.lineTo(w * 0.6, h * 0.5);
    path.lineTo(w * 0.65, h * 0.12);
    path.lineTo(w * 0.75, h * 0.95);
    path.lineTo(w * 0.8, h * 0.5);
    path.lineTo(w, h * 0.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
