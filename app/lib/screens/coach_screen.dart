import 'dart:async';

import 'package:flutter/material.dart';

import '../coach/coach_context_builder.dart';
import '../coach/coach_engine.dart';
import '../coach/gemma_coach_engine.dart';
import '../coach/coach_models.dart';
import '../coach/coach_response_validator.dart';
import '../coach/coach_safety_router.dart';
import '../data/real_data.dart';
import '../theme/app_colors.dart';

class CoachScreen extends StatefulWidget {
  final WellnessViewSnapshot? snapshot;
  final CoachEngine? engine;

  const CoachScreen({
    super.key,
    this.snapshot,
    this.engine,
  });

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> with WidgetsBindingObserver {
  final _question = TextEditingController();
  final _router = const CoachSafetyRouter();
  final _contextBuilder = const CoachContextBuilder();
  late final CoachEngine _engine;
  CancellationToken? _cancellation;
  CoachValidated? _response;
  CoachBoundaryResponse? _boundary;
  bool _generating = false;

  WellnessViewSnapshot? get _snapshot =>
      widget.snapshot ?? RealData.wellnessSnapshot();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = widget.engine ?? GemmaCoachEngine();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _clear();
      unawaited(_engine.close());
    }
  }

  Future<void> _ask() async {
    final question = _question.text.trim();
    final route = _router.route(question);
    if (route != CoachRoute.allow) {
      setState(() {
        _boundary = _router.boundaryFor(route);
        _response = null;
      });
      return;
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      setState(() {
        _boundary = const CoachBoundaryResponse(
          title: 'Build your baseline first',
          body: 'Connect health data and let Signa learn your usual range '
              'before asking for an explanation.',
          actions: <CoachBoundaryAction>[],
        );
      });
      return;
    }

    final token = CancellationToken();
    _cancellation = token;
    setState(() {
      _generating = true;
      _boundary = null;
      _response = null;
    });
    final request = CoachRequest(
      context: _contextBuilder.build(snapshot, question),
      fallbackInsight: snapshot.insight,
    );
    var result = await _engine.generate(request, token);
    if (result is CoachRejected && !token.isCancelled) {
      result = await const DeterministicCoachEngine().generate(request, token);
    }
    if (!mounted) return;
    setState(() {
      _generating = false;
      _response = result is CoachValidated ? result : null;
    });
  }

  void _cancel() {
    _cancellation?.cancel();
    setState(() => _generating = false);
  }

  void _clear() {
    _cancellation?.cancel();
    _question.clear();
    if (!mounted) return;
    setState(() {
      _response = null;
      _boundary = null;
      _generating = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancellation?.cancel();
    unawaited(_engine.close());
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Signa')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private wellness coach',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'For adults 18+. All question processing stays on this '
                    'phone. Signa explains approved facts; it does not diagnose, '
                    'recommend treatment, or monitor emergencies.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('coach_question'),
              controller: _question,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ask about your score or recent pattern',
                hintText: 'Why did sleep stand out this week?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_generating)
              FilledButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Cancel'),
              )
            else
              FilledButton.icon(
                key: const Key('coach_submit'),
                onPressed: _ask,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Ask Signa'),
              ),
            if (_boundary case final boundary?) ...[
              const SizedBox(height: 20),
              _BoundaryCard(boundary: boundary),
            ],
            if (_response case final response?) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grounded Signa explanation',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(response.text),
                    const SizedBox(height: 12),
                    Text(
                      'Evidence: ${response.evidenceIds.join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            if (_response != null || _boundary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clear,
                child: const Text('Clear conversation'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  final CoachBoundaryResponse boundary;

  const _BoundaryCard({required this.boundary});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              boundary.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(boundary.body),
          ],
        ),
      );
}
