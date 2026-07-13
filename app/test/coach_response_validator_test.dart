import 'package:flutter_test/flutter_test.dart';
import 'package:signa/coach/coach_models.dart';
import 'package:signa/coach/coach_response_validator.dart';

void main() {
  const context = CoachContext(
    question: 'Why did my score change?',
    facts: <CoachFact>[
      CoachFact('fact_score', 'Current score is 72 with high confidence.'),
      CoachFact('fact_sleep', 'Sleep differed from your usual range.'),
    ],
  );
  const validator = CoachResponseValidator();

  test('accepts grounded JSON with an allowlisted action', () {
    const raw =
        '{"text":"Sleep differed from your usual range.","evidence":["fact_sleep"],"action":"protect_sleep_window","category":"explanation"}';

    final result = validator.validate(raw, context);

    expect(result, isA<CoachValidated>());
    expect((result as CoachValidated).actionId, 'protect_sleep_window');
  });

  test('rejects unknown evidence and action IDs', () {
    const raw =
        '{"text":"Take medication.","evidence":["invented"],"action":"stop_medication","category":"explanation"}';

    expect(validator.validate(raw, context), isA<CoachRejected>());
  });

  test('rejects extra keys and medical or causal claims', () {
    const withExtra =
        '{"text":"This is fine.","evidence":["fact_score"],"action":null,"category":"explanation","raw_hrv":42}';
    const causal =
        '{"text":"Poor sleep caused depression.","evidence":["fact_sleep"],"action":null,"category":"explanation"}';

    expect(validator.validate(withExtra, context), isA<CoachRejected>());
    expect(validator.validate(causal, context), isA<CoachRejected>());
  });

  test('rejects evidence-free and overlong responses', () {
    final longText = 'a' * 601;
    final raw =
        '{"text":"$longText","evidence":[],"action":null,"category":"explanation"}';

    expect(validator.validate(raw, context), isA<CoachRejected>());
  });
}
