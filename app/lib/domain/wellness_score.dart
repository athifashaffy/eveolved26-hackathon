enum ScoreConfidence { unavailable, low, medium, high }

enum BaselineState { learning, ready, stale, recalibrating }

enum ScoreComponent { hrv, sleep, activity, mood }

class ComponentContribution {
  final int score;
  final double weight;
  final String explanation;

  const ComponentContribution({
    required this.score,
    required this.weight,
    required this.explanation,
  });
}

class WellnessScore {
  final DateTime date;
  final int? score;
  final String scoreVersion;
  final BaselineState state;
  final ScoreConfidence confidence;
  final int eligibleDays;
  final Map<ScoreComponent, ComponentContribution> contributions;

  const WellnessScore({
    required this.date,
    required this.score,
    required this.scoreVersion,
    required this.state,
    required this.confidence,
    required this.eligibleDays,
    this.contributions = const <ScoreComponent, ComponentContribution>{},
  });

  Map<ScoreComponent, double> get appliedWeights =>
      contributions.map((key, value) => MapEntry(key, value.weight));
}
