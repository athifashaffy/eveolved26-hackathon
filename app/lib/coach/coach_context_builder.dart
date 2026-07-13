import '../data/real_data.dart';
import '../domain/timeline_marker.dart';
import 'coach_models.dart';

/// Converts the current view into the smallest reviewed fact set needed for a
/// coach explanation. Raw wearable records are deliberately never serialized.
class CoachContextBuilder {
  const CoachContextBuilder();

  CoachContext build(
    WellnessViewSnapshot snapshot,
    String question, {
    List<String> markerCategories = const <String>[],
  }) {
    final wellness = snapshot.wellness;
    final facts = <CoachFact>[
      CoachFact(
        'fact_score',
        wellness.score == null
            ? 'A numeric Signa Score is unavailable while the personal baseline is ${wellness.state.name}.'
            : 'Current Signa Score is ${wellness.score} with ${wellness.confidence.name} confidence.',
      ),
      for (final contribution in wellness.contributions.entries)
        CoachFact(
          'fact_${contribution.key.name}',
          contribution.value.explanation,
        ),
      CoachFact(
        'fact_insight',
        '${snapshot.insight.title}. ${snapshot.insight.body}',
      ),
    ];
    final allowedCategories =
        TimelineMarkerCategory.values.map((category) => category.name).toSet();

    return CoachContext(
      question: question.trim(),
      facts: facts,
      markerCategories: markerCategories
          .where(allowedCategories.contains)
          .toSet()
          .toList(growable: false),
    );
  }
}
