import '../scoring/insight_engine.dart';
import 'coach_models.dart';
import 'coach_response_validator.dart';

class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class CoachRequest {
  final CoachContext context;
  final WellnessInsight fallbackInsight;

  const CoachRequest({
    required this.context,
    required this.fallbackInsight,
  });
}

abstract interface class CoachEngine {
  Future<CoachValidationResult> generate(
    CoachRequest request,
    CancellationToken cancellation,
  );

  Future<void> close();
}

class DeterministicCoachEngine implements CoachEngine {
  const DeterministicCoachEngine();

  @override
  Future<CoachValidationResult> generate(
    CoachRequest request,
    CancellationToken cancellation,
  ) async {
    if (cancellation.isCancelled) {
      return const CoachRejected('cancelled');
    }
    return CoachValidated(
      text: '${request.fallbackInsight.title}. ${request.fallbackInsight.body}',
      evidenceIds: const <String>['fact_insight'],
      actionId: request.fallbackInsight.actionId,
      category: 'explanation',
    );
  }

  @override
  Future<void> close() async {}
}
