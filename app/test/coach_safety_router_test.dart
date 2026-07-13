import 'package:flutter_test/flutter_test.dart';
import 'package:signa/coach/coach_models.dart';
import 'package:signa/coach/coach_safety_router.dart';

void main() {
  final cases = <String, CoachRoute>{
    'I want to kill myself': CoachRoute.crisis,
    'I am not suicidal': CoachRoute.crisis,
    'I want to hurt myself': CoachRoute.crisis,
    'Should I stop taking sertraline?': CoachRoute.medication,
    'What dose of my medication should I take?': CoachRoute.medication,
    'Do I have depression?': CoachRoute.diagnosisTreatment,
    'What treatment should I get?': CoachRoute.diagnosisTreatment,
    'Why was my score lower this week?': CoachRoute.allow,
    'How can I protect my sleep window?': CoachRoute.allow,
    '': CoachRoute.unsupported,
    List<String>.filled(501, 'a').join(): CoachRoute.unsupported,
  };

  for (final entry in cases.entries) {
    test('routes input to ${entry.value.name}', () {
      expect(const CoachSafetyRouter().route(entry.key), entry.value);
    });
  }

  test('boundary copy does not claim monitoring or medical advice', () {
    final response = const CoachSafetyRouter().boundaryFor(CoachRoute.crisis);

    expect(response.title, isNotEmpty);
    expect(response.body.toLowerCase(), isNot(contains('monitor')));
    expect(response.body.toLowerCase(), isNot(contains('medical advice')));
    expect(response.actions, contains(CoachBoundaryAction.crisisSupport));
  });
}
