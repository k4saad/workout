import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/features/progress/widgets/compare_widgets.dart';
import 'package:path/path.dart' as p;

/// A 1x1 PNG. Enough for Image.file to decode without bundling a fixture.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  late Directory tmp;
  late List<File> frames;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kt_progress_');
    frames = [
      for (var i = 0; i < 4; i++)
        File(p.join(tmp.path, 'frame$i.png'))..writeAsBytesSync(_png),
    ];
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // Scrolling, as on the Photos screen: a 9:16 frame and its controls are
  // taller than the test window.
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );

  group('WipeCompare', () {
    testWidgets('renders both images with a divider', (tester) async {
      await tester.pumpWidget(
        wrap(
          AspectRatio(
            aspectRatio: 3 / 4,
            child: WipeCompare(
              before: frames[0],
              after: frames[1],
              beforeLabel: '28 Sep',
              afterLabel: '23 Nov',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text('28 Sep'), findsOneWidget);
      expect(find.text('23 Nov'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging moves the divider', (tester) async {
      await tester.pumpWidget(
        wrap(
          AspectRatio(
            aspectRatio: 3 / 4,
            child: WipeCompare(before: frames[0], after: frames[1]),
          ),
        ),
      );
      await tester.pump();

      final handle = find.byIcon(Icons.drag_indicator);
      final before = tester.getCenter(handle).dx;

      await tester.drag(find.byType(WipeCompare), const Offset(-80, 0));
      await tester.pump();

      final after = tester.getCenter(handle).dx;
      expect(after, lessThan(before));
    });

    testWidgets('the divider cannot be dragged off the edge', (tester) async {
      await tester.pumpWidget(
        wrap(
          AspectRatio(
            aspectRatio: 3 / 4,
            child: WipeCompare(before: frames[0], after: frames[1]),
          ),
        ),
      );
      await tester.pump();
      await tester.drag(find.byType(WipeCompare), const Offset(-9999, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(WipeCompare), const Offset(9999, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Flipbook', () {
    testWidgets('starts on the first frame and scrubs forward', (tester) async {
      await tester.pumpWidget(
        wrap(
          Flipbook(
            frames: frames,
            captions: const ['28 Sep', '26 Oct', '23 Nov', '21 Dec'],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('28 Sep'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('26 Oct'), findsOneWidget);
    });

    testWidgets('cannot scrub past either end', (tester) async {
      await tester.pumpWidget(wrap(Flipbook(frames: frames)));
      await tester.pump();

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('play advances the frames and pause stops it', (tester) async {
      await tester.pumpWidget(
        wrap(Flipbook(frames: frames, captions: const ['a', 'b', 'c', 'd'])),
      );
      await tester.pump();
      expect(find.text('a'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1150));
      expect(find.text('b'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('b'), findsOneWidget, reason: 'paused means paused');
    });

    testWidgets('a frame fades into the next rather than cutting', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(Flipbook(frames: frames, captions: const ['a', 'b', 'c', 'd'])),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byType(Image),
        findsNWidgets(2),
        reason: 'both frames on screen, mid-fade',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a single frame cannot autoplay', (tester) async {
      await tester.pumpWidget(wrap(Flipbook(frames: [frames.first])));
      await tester.pump();
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an empty flipbook says so rather than crashing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Flipbook(frames: [])));
      await tester.pump();
      expect(find.textContaining('No photos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SideBySide', () {
    testWidgets('shows both photos with their captions', (tester) async {
      await tester.pumpWidget(
        wrap(
          SideBySide(
            before: frames[0],
            after: frames[1],
            beforeCaption: 'Week 1 · 50.2 kg',
            afterCaption: 'Week 12 · 55.8 kg',
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.textContaining('50.2 kg'), findsOneWidget);
      expect(find.textContaining('55.8 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
