import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/real_data.dart';
import '../data/models.dart';
import '../domain/wellness_score.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/status_badge.dart';
import '../widgets/top_app_bar.dart';

class HomeScreen extends StatelessWidget {
  final WellnessViewSnapshot? snapshotOverride;

  const HomeScreen({super.key, this.snapshotOverride});

  @override
  Widget build(BuildContext context) {
    final wellnessView = snapshotOverride ?? RealData.wellnessSnapshot();
    if (wellnessView != null) {
      return _WellnessToday(view: wellnessView);
    }
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
                        label: 'SLEEP LAST NIGHT',
                        value: snap.sleepMinutes > 0
                            ? '${snap.sleepMinutes ~/ 60}h ${(snap.sleepMinutes % 60).toString().padLeft(2, '0')}m'
                            : snap.sleepScore.toString(),
                        unit: snap.sleepMinutes > 0 ? '' : '/100',
                        delta: snap.sleepTrendLabel,
                        deltaUp: null,
                        accent: AppColors.sparkAmber,
                        trend: _curveFlat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Steps card
                if (snap.last30Days.isNotEmpty) _StepsCard(snap: snap),
                if (snap.last30Days.isNotEmpty) const SizedBox(height: 16),
                _DailyHistoryCard(snap: snap),
                const SizedBox(height: 16),
                _DeviceTile(snap: snap),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/trends'),
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('Understand recent changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<double> _curveUp = [
    0.85,
    0.8,
    0.78,
    0.65,
    0.55,
    0.4,
    0.3,
    0.15
  ];
  static const List<double> _curveFlat = [
    0.55,
    0.5,
    0.55,
    0.5,
    0.55,
    0.5,
    0.55,
    0.5
  ];
}

class _WellnessToday extends StatelessWidget {
  final WellnessViewSnapshot view;

  const _WellnessToday({required this.view});

  @override
  Widget build(BuildContext context) {
    final wellness = view.wellness;
    final learning = wellness.score == null;
    return SignaScaffold(
      currentRoute: '/home',
      child: Column(
        children: [
          const SignaAppBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: learning
                      ? _LearningContent(wellness: wellness)
                      : _ReadyContent(view: view),
                ),
                const SizedBox(height: 16),
                _InsightPanel(view: view),
                if (view.syncIssue != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'The latest sync did not finish. Your last saved view is still available.',
                    style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningContent extends StatelessWidget {
  final WellnessScore wellness;

  const _LearningContent({required this.wellness});

  @override
  Widget build(BuildContext context) {
    final progress = (wellness.eligibleDays / 10).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wellness.state == BaselineState.recalibrating
              ? 'Relearning your baseline'
              : 'Learning your baseline',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${wellness.eligibleDays} of 10 eligible days',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
          color: AppColors.primaryContainer,
          backgroundColor: AppColors.surfaceContainerHigh,
        ),
        const SizedBox(height: 16),
        Text(
          'Keep wearing your device',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'An eligible day includes sleep plus HRV or activity. Signa will not show a score until it has enough of your own data.',
          style: GoogleFonts.inter(
            height: 1.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReadyContent extends StatelessWidget {
  final WellnessViewSnapshot view;

  const _ReadyContent({required this.view});

  @override
  Widget build(BuildContext context) {
    final wellness = view.wellness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Signa Score',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${wellness.score} / 100',
          style: GoogleFonts.manrope(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_confidenceName(wellness.confidence)} confidence',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        ...wellness.contributions.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              entry.value.explanation,
              style: GoogleFonts.inter(
                height: 1.4,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _confidenceName(ScoreConfidence confidence) => switch (confidence) {
        ScoreConfidence.unavailable => 'Unavailable',
        ScoreConfidence.low => 'Low',
        ScoreConfidence.medium => 'Medium',
        ScoreConfidence.high => 'High',
      };
}

class _InsightPanel extends StatelessWidget {
  final WellnessViewSnapshot view;

  const _InsightPanel({required this.view});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              view.insight.title,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              view.insight.body,
              style: GoogleFonts.inter(
                height: 1.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
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
    final isDemo = snap.deviceName == 'Demo Data';
    final isDisconnected = snap.deviceName == 'No device connected';
    final indicatorColor = isDisconnected ? Colors.orange : Colors.green;
    final subtitle = isDemo
        ? 'Connect Fitbit for real data'
        : isDisconnected
            ? 'Tap to connect a device'
            : 'Last synced: ${snap.lastSync.inMinutes}m ago';

    return InkWell(
      onTap: isDisconnected ? () => context.go('/connect') : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
              child: Icon(
                isDisconnected ? Icons.watch_off_outlined : Icons.watch,
                color: AppColors.onSecondaryContainer,
              ),
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
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            isDisconnected
                ? const Icon(Icons.chevron_right, color: AppColors.outline)
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: indicatorColor.withOpacity(0.25),
                        width: 4,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final StabilitySnapshot snap;
  const _StepsCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final today = snap.last30Days.isNotEmpty ? snap.last30Days.last : null;
    final steps = today?.steps ?? 0;
    const goal = 10000;
    final pct = (steps / goal).clamp(0.0, 1.0);
    final last7 = snap.last30Days.length >= 7
        ? snap.last30Days.sublist(snap.last30Days.length - 7)
        : snap.last30Days;
    final avgSteps = last7.isEmpty
        ? 0
        : last7.map((r) => r.steps).reduce((a, b) => a + b) ~/ last7.length;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STEPS TODAY', style: AppTheme.labelUppercase()),
              Text(
                '$steps / $goal',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? Colors.green : AppColors.primaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '7-day avg: $avgSteps steps',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
