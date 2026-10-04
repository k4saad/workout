import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/quote_providers.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/domain/content/quotes.dart';
import 'package:keller_twelve/features/launch/launch_gate.dart';

/// The quote that opens the day — once, and never in the way.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  const quote = Quote(
    id: 'r-marcus-5-1',
    tradition: QuoteTradition.roman,
    text:
        'In the morning when thou risest unwillingly, let this thought be '
        'present,--I am rising to the work of a human being.',
    attribution: 'Marcus Aurelius, Meditations 5.1',
    translator: 'George Long (1862)',
  );

  Future<void> open(
    WidgetTester tester, {
    Preferences prefs = const Preferences(),
    bool fresh = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          preferencesProvider.overrideWith(() => _Prefs(prefs)),
          quoteOfDayProvider.overrideWith(
            (ref) async => (quote: quote, fresh: fresh),
          ),
          openRunProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => LaunchGate(
            now: () => DateTime(2026, 10, 19, 6, 40),
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('underneath'))),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('greets him by name with the day’s quote', (tester) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Good morning, Saad.'), findsOneWidget);
    expect(find.text(quote.text), findsOneWidget);
    expect(find.text(quote.attribution), findsOneWidget);
    expect(find.text('George Long (1862)'), findsOneWidget);
  });

  testWidgets('a tap moves it on, and the app is there underneath', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text(quote.text));
    // The fade starts on the next frame and runs its course.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(quote.text), findsNothing);
    expect(find.text('underneath'), findsOneWidget);
  });

  testWidgets('it steps aside by itself once there was time to read it', (
    tester,
  ) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(quote.text), findsNothing);
  });

  testWidgets('switched off in Settings, it never shows', (tester) async {
    await open(tester, prefs: const Preferences(launchQuote: false));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(quote.text), findsNothing);
  });

  testWidgets('a second open the same day goes straight in', (tester) async {
    await open(tester, fresh: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(quote.text), findsNothing);
  });

  testWidgets('a session waiting to be resumed comes first', (tester) async {
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            programmeId: 'keller-twelve',
            blockId: 'foundation',
            dayId: 'f-tue',
            weekNo: 1,
            plannedDate: DateTime(2026, 9, 28),
            scheduledDate: DateTime(2026, 9, 28),
            status: const Value(SessionStatus.inProgress),
          ),
        );
    await open(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(quote.text), findsNothing);
  });
}

class _Prefs extends PreferencesNotifier {
  _Prefs(this.prefs);
  final Preferences prefs;
  @override
  Future<Preferences> build() async => prefs;
}
