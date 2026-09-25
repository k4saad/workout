import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_service.dart';
import '../domain/content/quotes.dart';
import 'providers.dart';
import 'settings_providers.dart';

final quoteBookProvider = FutureProvider<QuoteBook>(
  (ref) => ref.watch(programmeRepositoryProvider).loadQuotes(),
);

/// The quote of the day, and whether it is new today.
///
/// The first time the app opens on a date, a quote not yet shown this round
/// is chosen and remembered; every later look that day — the launch
/// screen, Today — gets the same one. [fresh] is what the launch screen
/// asks: it greets him once a day, not six times.
typedef DailyQuote = ({Quote quote, bool fresh});

final quoteOfDayProvider = FutureProvider<DailyQuote?>((ref) async {
  final book = await ref.watch(quoteBookProvider.future);
  if (book.isEmpty) return null;
  final today = ref.watch(todayProvider);

  // Read, not watched: choosing today's quote writes the preferences, and
  // watching them would choose again.
  Preferences prefs;
  try {
    prefs = await ref.read(preferencesProvider.future);
  } on Object {
    prefs = const Preferences();
  }

  final pick = quoteForDay(
    day: today,
    pool: [for (final q in book.quotes) q.id],
    lastDay: prefs.quoteDay,
    lastId: prefs.quoteId,
    cycle: prefs.recentQuoteIds,
  );
  if (pick.fresh) {
    try {
      await ref
          .read(preferencesProvider.notifier)
          .set(
            prefs.withQuoteOfDay(day: today, id: pick.id, cycle: pick.cycle),
          );
    } on Object {
      // Not remembered: tomorrow's choice may repeat today's. Harmless.
    }
  }
  final quote = book.byId(pick.id);
  return quote == null ? null : (quote: quote, fresh: pick.fresh);
});
