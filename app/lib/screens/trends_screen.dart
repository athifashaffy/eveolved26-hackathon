import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/real_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/signa_scaffold.dart';
import '../widgets/top_app_bar.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _range = 1; // 0 = 7d, 1 = 30d, 2 = 90d

  @override
  Widget build(BuildContext context) {
    final snap = RealData.snapshot();
    return SignaScaffold(
      currentRoute: '/trends',
      child: Column(
        children: [
          const SignaAppBar(title: 'Signa'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Text('Trends',
                    style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryContainer)),
                const SizedBox(height: 16),
                _Segmented(
                  current: _range,
                  onChange: (v) => setState(() => _range = v),
                ),
                const SizedBox(height: 24),
                _ChartCard(readings: snap.last30Days),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final rs = snap.last30Days;
                  final avg = rs.isEmpty
                      ? 0.0
                      : rs.map((r) => r.score).reduce((a, b) => a + b) / rs.length;
                  final lowest = rs.isEmpty
                      ? 0.0
                      : rs.map((r) => r.score).reduce((a, b) => a < b ? a : b);
                  final daysBelow = rs.where((r) => r.score < 0.5).length;
                  return Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                            label: 'AVG SCORE',
                            value: avg.toStringAsFixed(2),
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryTile(
                            label: 'LOWEST',
                            value: lowest.toStringAsFixed(2),
                            color: AppColors.error),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryTile(
                            label: 'DAYS BELOW',
                            value: daysBelow.toString(),
                            color: AppColors.primary),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixed.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.tertiaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alert sent to clinician on Mar 15',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onTertiaryFixedVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _InsightCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChange;
  const _Segmented({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const labels = ['7 Days', '30 Days', '90 Days'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? Colors.white
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<StabilityReading> readings;
  const _ChartCard({required this.readings});

  @override
  Widget build(BuildContext context) {
    final spots = readings
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.score))
        .toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HRV × Sleep Interaction',
                      style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text('LAST 30 DAYS',
                        style: AppTheme.labelUppercase(size: 10)),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Score',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant))
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.outlineVariant.withOpacity(0.4),
                    strokeWidth: 1,
                    dashArray: [4, 6],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 7,
                      getTitlesWidget: (v, _) {
                        final i = v.round();
                        if (i < 0 || i >= readings.length) return const SizedBox.shrink();
                        const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
                        final d = readings[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}',
                            style: AppTheme.labelUppercase(size: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: 0.5,
                    color: AppColors.error.withOpacity(0.5),
                    strokeWidth: 1.5,
                    dashArray: [6, 6],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                      labelResolver: (_) => 'PHQ-9 ≥ 5',
                    ),
                  ),
                ]),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color: AppColors.primaryContainer,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (s, _) =>
                          s.y < 0.5 || s.x == spots.length - 1,
                      getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: s.y < 0.5
                            ? AppColors.error
                            : AppColors.primaryContainer,
                        strokeColor: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryContainer.withOpacity(0.18),
                          AppColors.primaryContainer.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(label, style: AppTheme.labelUppercase(size: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
                fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: AppColors.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Text('Clinical Insight',
                  style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSecondaryContainer)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your interaction score recovered significantly following the March 15 adjustment. Continue monitoring sleep quality indicators.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}
