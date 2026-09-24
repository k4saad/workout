import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/domain/models/exercise.dart';
import 'package:keller_twelve/domain/motion/motion.dart';
import 'package:keller_twelve/features/exercises/widgets/motion_demo.dart';

import '../support/screenshot.dart';

/// Every demo clip, frame by frame, on contact sheets:
/// `build/screens/motions/sheet_N.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/motion_sheet_test.dart
///
/// The rig tests prove no bone stretches and no foot skates. Only looking
/// proves a squat looks like a squat.
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  testWidgets('motion contact sheets', skip: !_enabled, (tester) async {
    await Screenshot.loadRealFonts();
    final lib = MotionLibrary.fromJson(
      jsonDecode(File('assets/exercises/motions.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final exercises = ExerciseLibrary.fromJson(
      jsonDecode(File('assets/exercises/exercises.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    // Colour each clip with the muscles of the first exercise that uses it.
    final firstUser = <String, Exercise>{};
    for (final e in exercises.exercises) {
      final clip = lib.forExercise(e.id);
      if (clip != null) firstUser.putIfAbsent(clip.id, () => e);
    }

    const perSheet = 5;
    const frames = 6;
    const cellW = 180.0;
    const rowH = 200.0;
    // CLIP=squat,row renders only clips whose id contains one of those.
    final only = Platform.environment['CLIP']?.split(',');
    final clips = lib.clips.values
        .where((c) => only == null || only.any(c.id.contains))
        .toList();

    for (var s = 0; s * perSheet < clips.length; s++) {
      final chunk = clips.skip(s * perSheet).take(perSheet).toList();
      tester.view.physicalSize = Size(
        frames * cellW * 2,
        chunk.length * rowH * 2,
      );
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Screenshot.frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Screenshot.themed(AppTheme.dark),
            home: Scaffold(
              body: Column(
                children: [
                  for (final clip in chunk)
                    SizedBox(
                      height: rowH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                            child: Text(
                              '${clip.id}  ·  ${clip.view.name}  ·  '
                              '${clip.periodMs} ms  ·  '
                              '${firstUser[clip.id]?.id ?? '(unused)'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textDim,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                for (var k = 0; k < frames; k++)
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      color: AppTheme.surface,
                                      child: MotionFigure(
                                        clip: clip,
                                        skeleton: lib.skeleton,
                                        primary: lib.regionsForAll(
                                          firstUser[clip.id]?.primaryMuscles ??
                                              const [],
                                        ),
                                        secondary: lib.regionsForAll(
                                          firstUser[clip.id]
                                                  ?.secondaryMuscles ??
                                              const [],
                                        ),
                                        animate: false,
                                        at: k / frames,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await Screenshot.capture(tester, 'motions/sheet_$s');
    }
  });
}
