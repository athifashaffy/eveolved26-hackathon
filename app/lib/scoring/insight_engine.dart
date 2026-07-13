import '../domain/wellness_score.dart';

class WellnessInsight {
  final String title;
  final String body;
  final String actionId;
  final List<ScoreComponent> evidence;

  const WellnessInsight({
    required this.title,
    required this.body,
    required this.actionId,
    this.evidence = const <ScoreComponent>[],
  });
}

class InsightEngine {
  const InsightEngine();

  static const allowedActions = <String>{
    'protect_sleep_window',
    'complete_check_in',
    'review_recent_change',
    'prepare_clinician_questions',
    'view_trend',
  };

  WellnessInsight build(WellnessScore score) {
    switch (score.state) {
      case BaselineState.learning:
        return WellnessInsight(
          title: 'Learning your baseline',
          body:
              '${score.eligibleDays} of 10 eligible days collected. Keep wearing your device and add an optional check-in.',
          actionId: 'complete_check_in',
        );
      case BaselineState.recalibrating:
        return const WellnessInsight(
          title: 'Adjusting to your data source',
          body:
              'Signa is learning the usual range for this source before comparing daily changes.',
          actionId: 'review_recent_change',
        );
      case BaselineState.stale:
        return const WellnessInsight(
          title: 'New data will refresh this view',
          body:
              'Your latest available signals are several days old. Review the trend after your next sync.',
          actionId: 'view_trend',
        );
      case BaselineState.ready:
        return _readyInsight(score);
    }
  }

  WellnessInsight _readyInsight(WellnessScore score) {
    if (score.contributions.isEmpty) {
      return const WellnessInsight(
        title: 'Your baseline is ready',
        body: 'Review how your available signals have moved over time.',
        actionId: 'view_trend',
      );
    }
    final ordered = score.contributions.entries.toList()
      ..sort((left, right) => left.value.score.compareTo(right.value.score));
    final lowest = ordered.first;
    final highest = ordered.last;
    final lowName = _name(lowest.key);
    final highName = _name(highest.key);
    final evidence = lowest.key == highest.key
        ? <ScoreComponent>[lowest.key]
        : <ScoreComponent>[lowest.key, highest.key];

    return WellnessInsight(
      title: 'A mixed pattern in your recent signals',
      body:
          '$lowName differed most from your usual range, while $highName stayed closest. This describes change, not a diagnosis or cause.',
      actionId: lowest.key == ScoreComponent.sleep
          ? 'protect_sleep_window'
          : lowest.key == ScoreComponent.mood
              ? 'complete_check_in'
              : 'review_recent_change',
      evidence: evidence,
    );
  }

  String _name(ScoreComponent component) => switch (component) {
        ScoreComponent.hrv => 'HRV',
        ScoreComponent.sleep => 'Sleep',
        ScoreComponent.activity => 'Activity',
        ScoreComponent.mood => 'Mood',
      };
}
