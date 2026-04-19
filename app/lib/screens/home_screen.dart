import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/real_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/status_badge.dart';
import '../widgets/top_app_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snap = RealData.snapshot();
    return SignaScaffold(
      currentRoute: '/home',
      child: Column(
        children: [
          const SignaAppBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _StabilityCard(snap: snap),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'HRV TREND',
                        value: snap.hrvMs.toString(),
                        unit: 'ms',
                        delta: '+${snap.hrvDeltaPct.toStringAsFixed(0)}%',
                        deltaUp: true,
                        accent: AppColors.sparkGreen,
                        trend: _curveUp,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'SLEEP QUALITY',
                        value: snap.sleepScore.toString(),
                        unit: '/100',
                        delta: snap.sleepTrendLabel,
                        deltaUp: null,
                        accent: AppColors.sparkAmber,
                        trend: _curveFlat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DailyHistoryCard(snap: snap),
                const SizedBox(height: 16),
                _DeviceTile(snap: snap),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/alert'),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('View recent alert'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<double> _curveUp = [
    0.85, 0.8, 0.78, 0.65, 0.55, 0.4, 0.3, 0.15
  ];
  static const List<double> _curveFlat = [
    0.55, 0.5, 0.55, 0.5, 0.55, 0.5, 0.55, 0.5
  ];
}

class _StabilityCard extends StatelessWidget {
  final StabilitySnapshot snap;
  const _StabilityCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stability Score',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryContainer,
              )),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 192,
              height: 192,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(192, 192),
                    painter: _GaugePainter(progress: snap.score),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(snap.score * 100).round()}%',
                        style: GoogleFonts.manrope(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: snap.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LAST 14 DAYS', style: AppTheme.labelUppercase()),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up,
                        size: 14, color: AppColors.onTertiaryFixedVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Moderate Improvement',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onTertiaryFixedVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0..1
  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    final track = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final fg = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}

class _MetricCard extends StatelessWidget {
  final String label, value, unit, delta;
  final bool? deltaUp; // true up, false down, null flat
  final Color accent;
  final List<double> trend;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.delta,
    required this.deltaUp,
    required this.accent,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final deltaColor = deltaUp == true
        ? AppColors.sparkGreen
        : deltaUp == false
            ? AppColors.error
            : AppColors.sparkAmber;
    final deltaIcon = deltaUp == true
        ? Icons.arrow_upward
        : deltaUp == false
            ? Icons.arrow_downward
            : Icons.trending_flat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.labelUppercase()),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: CustomPaint(
              size: const Size(double.infinity, 40),
              painter: _SparkPainter(points: trend, color: accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(deltaIcon, size: 14, color: deltaColor),
              const SizedBox(width: 2),
              Text(
                delta,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _SparkPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final dx = size.width / (points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _DailyHistoryCard extends StatelessWidget {
  final StabilitySnapshot snap;
  const _DailyHistoryCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Score History',
                        style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      'Your progress over the last two weeks',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('DETAILS',
                    style: AppTheme.labelUppercase(
                        color: AppColors.primaryContainer, size: 10)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: snap.last14Days.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final highlight = i >= 9; // last 5 days stronger
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: FractionallySizedBox(
                      heightFactor: r.score.clamp(0.1, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: highlight
                              ? AppColors.primaryContainer
                              : AppColors.primaryContainer.withOpacity(0.2),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(999)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('14 DAYS AGO', style: AppTheme.labelUppercase(size: 9)),
              Text('TODAY', style: AppTheme.labelUppercase(size: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final StabilitySnapshot snap;
  const _DeviceTile({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.watch,
                color: AppColors.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snap.deviceName,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(
                  'Last synced: ${snap.lastSync.inMinutes} minutes ago',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.shade100,
                width: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
