import 'dart:convert';

import 'package:flutter/services.dart';

import 'coach_engine.dart';
import 'coach_response_validator.dart';

/// Thin adapter to a telemetry-free native runtime. No network API is used by
/// this engine; the only payload is the already minimized fact context.
class GemmaCoachEngine implements CoachEngine {
  static const _defaultChannel = MethodChannel('signa/coach');
  static const _systemPrompt = '''
You are Signa's local wellness explainer. Use only the supplied facts.
Return one JSON object with exactly: text, evidence, action, category.
Evidence must contain supplied fact IDs. Action must be null or supplied.
Never diagnose, recommend treatment or medication, claim causality or
certainty, claim anyone was contacted, or invent a measurement.
''';

  final MethodChannel channel;
  final CoachResponseValidator validator;
  final DeterministicCoachEngine fallback;

  GemmaCoachEngine({
    this.channel = _defaultChannel,
    this.validator = const CoachResponseValidator(),
    this.fallback = const DeterministicCoachEngine(),
  });

  @override
  Future<CoachValidationResult> generate(
    CoachRequest request,
    CancellationToken cancellation,
  ) async {
    if (cancellation.isCancelled) {
      return const CoachRejected('cancelled');
    }
    try {
      final raw =
          await channel.invokeMethod<String>('generate', <String, Object>{
        'system': _systemPrompt,
        'context': jsonEncode(request.context.toJson()),
        'maxTokens': 256,
        'temperature': 0.1,
      });
      if (cancellation.isCancelled) {
        await channel.invokeMethod<void>('cancel');
        return const CoachRejected('cancelled');
      }
      if (raw == null) return fallback.generate(request, cancellation);
      final validated = validator.validate(raw, request.context);
      if (validated is CoachValidated) return validated;
      return fallback.generate(request, cancellation);
    } on PlatformException {
      return fallback.generate(request, cancellation);
    } on MissingPluginException {
      return fallback.generate(request, cancellation);
    }
  }

  @override
  Future<void> close() async {
    try {
      await channel.invokeMethod<void>('close');
    } on PlatformException {
      // Unsupported devices use deterministic insights.
    } on MissingPluginException {
      // Native runtime is intentionally optional.
    }
  }
}
