import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../../domain/planner/planner.dart';

/// The categories an entry of his own can have, with their glyphs.
const plannerCategories = <(String, String, IconData)>[
  ('exam', 'Exam', Icons.assignment_outlined),
  ('study', 'Study', Icons.menu_book_outlined),
  ('meeting', 'Meeting', Icons.groups_outlined),
  ('appointment', 'Appointment', Icons.event_note_outlined),
  ('other', 'Other', Icons.push_pin_outlined),
];

/// Every kind of stretch has its own glyph: colour never carries it alone.
IconData plannerIcon(PlanItem i) => switch (i.kind) {
  PlanKind.lecture => Icons.school_outlined,
  PlanKind.job => Icons.work_outline,
  PlanKind.prayer => Icons.mosque_outlined,
  PlanKind.travel => Icons.directions_bike,
  PlanKind.session => Icons.fitness_center,
  PlanKind.meal => Icons.restaurant,
  PlanKind.event =>
    plannerCategories
        .firstWhere(
          (c) => c.$1 == i.category,
          orElse: () => plannerCategories.last,
        )
        .$3,
};

/// The one accent belongs to the session; everything else is grey.
Color plannerColour(PlanKind kind) => switch (kind) {
  PlanKind.session => AppTheme.crimson,
  PlanKind.lecture => AppTheme.text,
  PlanKind.job => AppTheme.textDim,
  PlanKind.prayer => AppTheme.text,
  PlanKind.event => AppTheme.text,
  PlanKind.travel || PlanKind.meal => AppTheme.textFaint,
};

/// "Lecture", "Work" …: what a stretch is, in a word.
String plannerKindLabel(PlanItem i) => switch (i.kind) {
  PlanKind.lecture => i.optional ? 'Lecture · optional' : 'Lecture',
  PlanKind.job => 'Work',
  PlanKind.prayer => 'Prayer',
  PlanKind.travel => 'Travel',
  PlanKind.session => i.optional ? 'Training · optional' : 'Training',
  PlanKind.meal => 'Meal',
  PlanKind.event =>
    plannerCategories
        .firstWhere(
          (c) => c.$1 == i.category,
          orElse: () => plannerCategories.last,
        )
        .$2,
};

/// "10:15–11:45".
String plannerSpan(PlanItem i) => '${formatHhmm(i.start)}–${formatHhmm(i.end)}';

/// "1 h 30", "45 min".
String plannerLength(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}
