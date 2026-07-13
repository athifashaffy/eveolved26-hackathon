import 'coach_models.dart';

/// Routes high-risk requests before any model is loaded or called.
class CoachSafetyRouter {
  const CoachSafetyRouter();

  static final List<RegExp> _crisis = <RegExp>[
    RegExp(r'\b(suicid|kill myself|end my life|hurt myself|self harm)'),
    RegExp(r'\b(don t want to (live|be alive)|better off dead)\b'),
  ];
  static final List<RegExp> _medication = <RegExp>[
    RegExp(r'\b(medication|medicine|meds|pill|dosage|dose)\b'),
    RegExp(r'\b(sertraline|ssri|antidepressant|prozac|fluoxetine)\b'),
  ];
  static final List<RegExp> _diagnosisOrTreatment = <RegExp>[
    RegExp(r'\b(do i have|diagnos|am i depressed|clinical depression)\b'),
    RegExp(r'\b(treat(ment)?|therapy should|cure)\b'),
  ];

  CoachRoute route(String question) {
    final normalized = _normalize(question);
    if (normalized.isEmpty || normalized.length > 500) {
      return CoachRoute.unsupported;
    }
    if (_matches(normalized, _crisis)) return CoachRoute.crisis;
    if (_matches(normalized, _medication)) return CoachRoute.medication;
    if (_matches(normalized, _diagnosisOrTreatment)) {
      return CoachRoute.diagnosisTreatment;
    }
    return CoachRoute.allow;
  }

  CoachBoundaryResponse boundaryFor(CoachRoute route) => switch (route) {
        CoachRoute.crisis => const CoachBoundaryResponse(
            title: 'Please reach out now',
            body: 'Signa cannot help safely with this. If you may act now, '
                'call local emergency services. In Canada or the United States, '
                'call or text 988 for immediate crisis support. Stay with '
                'someone you trust if you can.',
            actions: <CoachBoundaryAction>[
              CoachBoundaryAction.emergencyServices,
              CoachBoundaryAction.crisisSupport,
              CoachBoundaryAction.contactClinician,
            ],
          ),
        CoachRoute.medication => const CoachBoundaryResponse(
            title: 'Check with a qualified professional',
            body: 'Signa cannot advise on medication, doses, starting, or '
                'stopping. Contact the prescriber or a pharmacist before making '
                'a change.',
            actions: <CoachBoundaryAction>[
              CoachBoundaryAction.contactClinician,
              CoachBoundaryAction.prepareClinicianQuestions,
            ],
          ),
        CoachRoute.diagnosisTreatment => const CoachBoundaryResponse(
            title: 'Use Signa as a conversation aid',
            body: 'Signa cannot diagnose a condition or recommend treatment. '
                'A qualified professional can assess the full picture.',
            actions: <CoachBoundaryAction>[
              CoachBoundaryAction.contactClinician,
              CoachBoundaryAction.prepareClinicianQuestions,
            ],
          ),
        CoachRoute.allow ||
        CoachRoute.unsupported =>
          const CoachBoundaryResponse(
            title: 'Try a wellness question',
            body: 'Ask about the score, its approved contributors, recent '
                'context categories, or a small wellness action.',
            actions: <CoachBoundaryAction>[],
          ),
      };

  static bool _matches(String value, List<RegExp> patterns) =>
      patterns.any((pattern) => pattern.hasMatch(value));

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp("[^a-z0-9']+"), ' ')
      .replaceAll("'", '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
