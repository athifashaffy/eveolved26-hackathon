import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/database_service.dart';
import '../data/models.dart';
import '../domain/timeline_marker.dart';
import '../theme/app_colors.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  double _mood = 3;
  double _sleep = 3;
  TimelineMarkerCategory? _category;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final now = DateTime.now();
    await DatabaseService.instance.upsertSelfReport(
      SelfReport(
        date: now,
        sleepRating: _sleep.round(),
        moodRating: _mood.round(),
        notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdAt: now,
      ),
    );
    if (_category != null) {
      await DatabaseService.instance.upsertTimelineMarker(
        TimelineMarker(
          id: 'marker-${now.microsecondsSinceEpoch}',
          date: now,
          category: _category!,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          createdAt: now,
        ),
      );
    }
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Daily check-in')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('How was your mood?',
                style: GoogleFonts.manrope(fontSize: 18)),
            Slider(
              value: _mood,
              min: 1,
              max: 5,
              divisions: 4,
              label: _mood.round().toString(),
              onChanged: (value) => setState(() => _mood = value),
            ),
            const SizedBox(height: 12),
            Text('How did you sleep?',
                style: GoogleFonts.manrope(fontSize: 18)),
            Slider(
              value: _sleep,
              min: 1,
              max: 5,
              divisions: 4,
              label: _sleep.round().toString(),
              onChanged: (value) => setState(() => _sleep = value),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<TimelineMarkerCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Add context (optional)',
                border: OutlineInputBorder(),
              ),
              items: TimelineMarkerCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(_label(category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Private note (optional)',
                helperText: 'Stored on this phone and excluded from Ask Signa.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _save, child: const Text('Save check-in')),
            TextButton(
              onPressed: () => context.go('/today'),
              child: const Text('Skip today'),
            ),
          ],
        ),
      );

  String _label(TimelineMarkerCategory category) => switch (category) {
        TimelineMarkerCategory.medication => 'Medication change',
        TimelineMarkerCategory.therapy => 'Therapy',
        TimelineMarkerCategory.illness => 'Illness',
        TimelineMarkerCategory.travel => 'Travel',
        TimelineMarkerCategory.stress => 'Stress',
        TimelineMarkerCategory.alcohol => 'Alcohol',
        TimelineMarkerCategory.custom => 'Something else',
      };
}
