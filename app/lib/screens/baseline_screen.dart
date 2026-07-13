import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/real_data.dart';
import '../theme/app_colors.dart';

class BaselineScreen extends StatelessWidget {
  const BaselineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final view = RealData.wellnessSnapshot();
    final days = view?.wellness.eligibleDays ?? 0;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learning your baseline',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$days of 10 eligible days',
                style: GoogleFonts.inter(fontSize: 18),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (days / 10).clamp(0, 1)),
              const SizedBox(height: 20),
              Text(
                'Keep wearing your device. Signa uses up to 14 days to collect at least 10 days with sleep and either HRV or activity.',
                style: GoogleFonts.inter(
                  height: 1.5,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/today'),
                  child: const Text('View today'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
