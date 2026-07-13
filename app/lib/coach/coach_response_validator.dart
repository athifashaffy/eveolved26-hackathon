import 'dart:convert';

import '../scoring/insight_engine.dart';
import 'coach_models.dart';

sealed class CoachValidationResult {
  const CoachValidationResult();
}

class CoachValidated extends CoachValidationResult {
  final String text;
  final List<String> evidenceIds;
  final String? actionId;
  final String category;

  const CoachValidated({
    required this.text,
    required this.evidenceIds,
    required this.actionId,
    required this.category,
  });
}

class CoachRejected extends CoachValidationResult {
  final String reason;

  const CoachRejected(this.reason);
}

class CoachResponseValidator {
  const CoachResponseValidator();

  static const _keys = <String>{'text', 'evidence', 'action', 'category'};
  static const _categories = <String>{'explanation', 'action'};
  static final _prohibited = RegExp(
    r'\b(diagnos(e|ed|is)|treat(ment)?|medicat(e|ion)|dose|caus(e|ed)|'
    r'definitely|certainly|guarantee|contacted (your )?(doctor|clinician)|'
    r'stop taking|start taking|suicid|self harm)\b',
    caseSensitive: false,
  );

  CoachValidationResult validate(String raw, CoachContext context) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const CoachRejected('invalid_json');
    }
    if (decoded is! Map<String, dynamic>) {
      return const CoachRejected('invalid_shape');
    }
    if (decoded.keys.toSet().length != _keys.length ||
        !decoded.keys.toSet().containsAll(_keys)) {
      return const CoachRejected('unexpected_keys');
    }

    final text = decoded['text'];
    final evidence = decoded['evidence'];
    final action = decoded['action'];
    final category = decoded['category'];
    if (text is! String || text.trim().isEmpty || text.length > 600) {
      return const CoachRejected('invalid_text');
    }
    if (_prohibited.hasMatch(text)) {
      return const CoachRejected('prohibited_claim');
    }
    if (category is! String || !_categories.contains(category)) {
      return const CoachRejected('invalid_category');
    }
    if (evidence is! List ||
        evidence.isEmpty ||
        evidence.any((id) => id is! String)) {
      return const CoachRejected('invalid_evidence');
    }
    final evidenceIds = evidence.cast<String>();
    final knownFacts = context.facts.map((fact) => fact.id).toSet();
    if (!evidenceIds.every(knownFacts.contains)) {
      return const CoachRejected('unknown_evidence');
    }
    if (action != null &&
        (action is! String || !InsightEngine.allowedActions.contains(action))) {
      return const CoachRejected('invalid_action');
    }

    return CoachValidated(
      text: text.trim(),
      evidenceIds: List<String>.unmodifiable(evidenceIds),
      actionId: action as String?,
      category: category,
    );
  }
}
