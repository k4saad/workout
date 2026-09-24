import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/motion/motion.dart';
import 'package:keller_twelve/features/exercises/exercise_detail_screen.dart';
import 'package:keller_twelve/features/exercises/exercise_library_screen.dart';
import 'package:keller_twelve/features/exercises/widgets/motion_demo.dart';
import 'package:keller_twelve/features/exercises/widgets/motion_painter.dart';

/// The exercise demos on screen: they draw, they loop, they hold still when
/// asked, and the painter knows every piece of kit the data uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final motions = MotionLibrary.fromJson(
    jsonDecode(File('assets/exercises/motions.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('the painter draws every prop motions.json uses', () {
    for (final clip in motions.clips.values) {
      for (final p in clip.props) {
        expect(
          MotionPainter.propTypes,
          contains(p.type),
          reason: '${clip.id} uses a ${p.type} nobody draws',
        );
      }
    }
  });

  test('every clip paints at every stage of its loop without throwing', () {
    // A NaN rectangle or an empty path shows up here, not on the phone.
    for (final clip in motions.clips.values) {
      final bounds = clip.bounds(motions.skeleton);
      for (var i = 0; i < 12; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        MotionPainter(
          clip: clip,
          skeleton: motions.skeleton,
          bounds: bounds,
          progress: AlwaysStoppedAnimation(i / 12),
          primary: const {BodyRegion.quads, BodyRegion.chest},
          secondary: const {BodyRegion.glutes},
        ).paint(canvas, const Size(320, 240));
        recorder.endRecording().dispose();
      }
    }
  });

  group('on screen', () {
    late Directory tmp;
    late AppDatabase db;
    late ProgrammeRepository repo;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('kt_motion_');
      db = AppDatabase.memory();
      repo = ProgrammeRepository(documentsDir: tmp);
      // rootBundle loads never finish inside the pumped zone: warm them.
      await repo.loadLibrary();
      await repo.loadMotions();
    });

    tearDown(() async {
      await db.close();
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows keeps the handle a moment longer.
      }
    });

    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      bool reduceMotion = false,
      Size size = const Size(400, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            programmeRepositoryProvider.overrideWithValue(repo),
            databaseProvider.overrideWithValue(db),
          ],
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: MaterialApp(theme: AppTheme.dark, home: child),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    testWidgets('a demo draws and keeps moving', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: SizedBox(
            width: 300,
            height: 220,
            child: ExerciseDemo(exerciseId: 'barbell-back-squat'),
          ),
        ),
      );
      expect(find.byType(MotionFigure), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion holds the still frame instead', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: SizedBox(
            width: 300,
            height: 220,
            child: ExerciseDemo(exerciseId: 'barbell-back-squat'),
          ),
        ),
        reduceMotion: true,
      );
      expect(find.byType(MotionFigure), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('an exercise with no clip shows a placeholder, not a hole', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: ExerciseDemo(exerciseId: 'my-own-invented-lift'),
          ),
        ),
      );
      expect(find.byType(MotionFigure), findsNothing);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    });

    testWidgets('the exercise screen leads with the demo, and a tap holds it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const ExerciseDetailScreen(exerciseId: 'goblet-squat'),
      );
      expect(find.byType(ExerciseDemo), findsOneWidget);
      expect(find.text('working muscles'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Pause the demo')), findsOneWidget);

      await tester.tap(find.byType(ExerciseDemo));
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('Play the demo')), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(find.byType(ExerciseDemo));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      semantics.dispose();
    });

    testWidgets('the library shows a still figure for every row, none moving', (
      tester,
    ) async {
      await pump(tester, const ExerciseLibraryScreen());
      expect(find.byType(ExerciseDemo), findsWidgets);
      // Thumbnails are still frames: a list of moving figures is noise.
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
