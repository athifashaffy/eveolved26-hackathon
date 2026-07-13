enum CoachRoute { allow, crisis, medication, diagnosisTreatment, unsupported }

enum CoachBoundaryAction {
  emergencyServices,
  crisisSupport,
  contactClinician,
  prepareClinicianQuestions,
}

class CoachBoundaryResponse {
  final String title;
  final String body;
  final List<CoachBoundaryAction> actions;

  const CoachBoundaryResponse({
    required this.title,
    required this.body,
    required this.actions,
  });
}

enum CoachAction {
  protectSleepWindow,
  completeCheckIn,
  reviewRecentChange,
  prepareClinicianQuestions,
  viewTrend,
}

extension CoachActionId on CoachAction {
  String get id => switch (this) {
        CoachAction.protectSleepWindow => 'protect_sleep_window',
        CoachAction.completeCheckIn => 'complete_check_in',
        CoachAction.reviewRecentChange => 'review_recent_change',
        CoachAction.prepareClinicianQuestions => 'prepare_clinician_questions',
        CoachAction.viewTrend => 'view_trend',
      };
}

class CoachFact {
  final String id;
  final String text;

  const CoachFact(this.id, this.text);

  Map<String, String> toJson() => <String, String>{'id': id, 'text': text};
}

class CoachContext {
  final String question;
  final List<CoachFact> facts;
  final List<String> markerCategories;

  const CoachContext({
    required this.question,
    required this.facts,
    this.markerCategories = const <String>[],
  });

  Map<String, Object> toJson() => <String, Object>{
        'question': question,
        'facts': facts.map((fact) => fact.toJson()).toList(),
        'marker_categories': markerCategories,
      };
}
