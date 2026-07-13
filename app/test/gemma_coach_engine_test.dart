import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signa/coach/coach_engine.dart';
import 'package:signa/coach/coach_models.dart';
import 'package:signa/coach/coach_response_validator.dart';
import 'package:signa/coach/gemma_coach_engine.dart';
import 'package:signa/scoring/insight_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('signa/coach');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('validates native output before returning model text', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return '{"text":"Sleep differed from your usual range.","evidence":["fact_sleep"],"action":"protect_sleep_window","category":"explanation"}';
    });
    final engine = GemmaCoachEngine(channel: channel);

    final result = await engine.generate(_request, CancellationToken());

    expect(result, isA<CoachValidated>());
    expect(received?.method, 'generate');
    expect(received?.arguments.toString(), isNot(contains('raw_hrv')));
  });

  test('native errors fall back to the reviewed Signa insight', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => throw PlatformException(code: 'unsupported'),
    );
    final engine = GemmaCoachEngine(channel: channel);

    final result = await engine.generate(_request, CancellationToken());

    expect(result, isA<CoachValidated>());
    expect((result as CoachValidated).text, contains('Mixed pattern'));
  });
}

const _request = CoachRequest(
  context: CoachContext(
    question: 'Explain this',
    facts: <CoachFact>[
      CoachFact('fact_sleep', 'Sleep differed from your usual range.'),
      CoachFact('fact_insight', 'Mixed pattern. Review your sleep window.'),
    ],
  ),
  fallbackInsight: WellnessInsight(
    title: 'Mixed pattern',
    body: 'Review your sleep window.',
    actionId: 'protect_sleep_window',
  ),
);
