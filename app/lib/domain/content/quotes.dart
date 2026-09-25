import 'dart:math';

/// Where a quote comes from.
enum QuoteTradition {
  /// The Qur'an, with surah and ayah.
  quran,

  /// A sahih hadith, with its collection and number.
  hadith,

  /// Greek writers, in public-domain translations.
  greek,

  /// Roman writers, in public-domain translations.
  roman;

  static QuoteTradition? fromJson(String? s) =>
      values.where((t) => t.name == s).firstOrNull;
}

/// One quote and exactly where it is from.
class Quote {
  const Quote({
    required this.id,
    required this.tradition,
    required this.text,
    required this.attribution,
    this.translator,
    this.verifiedAt,
  });

  final String id;
  final QuoteTradition tradition;
  final String text;

  /// "Qur’an 94:5–6", "Sahih al-Bukhari 6114", "Marcus Aurelius,
  /// Meditations 4.3".
  final String attribution;

  /// Whose English this is. Always a public-domain translation, or the
  /// meaning given plainly for a hadith.
  final String? translator;

  /// Where the reference was checked.
  final String? verifiedAt;

  static Quote? fromJson(Map<String, dynamic> j) {
    final tradition = QuoteTradition.fromJson(j['tradition'] as String?);
    if (tradition == null) return null;
    return Quote(
      id: j['id'] as String,
      tradition: tradition,
      text: j['text'] as String,
      attribution: j['attribution'] as String,
      translator: j['translator'] as String?,
      verifiedAt: j['verifiedAt'] as String?,
    );
  }
}

class QuoteBook {
  const QuoteBook(this.quotes);

  final List<Quote> quotes;

  bool get isEmpty => quotes.isEmpty;

  Quote? byId(String? id) => quotes.where((q) => q.id == id).firstOrNull;

  factory QuoteBook.fromJson(Map<String, dynamic> j) => QuoteBook([
    for (final q in (j['quotes'] as List? ?? const []))
      ?Quote.fromJson(q as Map<String, dynamic>),
  ]);
}

/// The next quote, and the round it belongs to.
///
/// [cycle] holds the ids shown in the current round, newest first. Nothing
/// in it comes back until every quote in [pool] has been shown; then a new
/// round starts, never opening with [last] — the one just read.
({String id, List<String> cycle}) nextQuote({
  required List<String> pool,
  required List<String> cycle,
  required String? last,
  Random? random,
}) {
  if (pool.isEmpty) throw ArgumentError('No quotes to choose from.');
  final rng = random ?? Random();
  final shown = {...cycle}..retainAll(pool);
  var left = [
    for (final id in pool)
      if (!shown.contains(id)) id,
  ];
  var fresh = false;
  if (left.isEmpty) {
    fresh = true;
    left = [
      for (final id in pool)
        if (id != last) id,
    ];
    if (left.isEmpty) left = [...pool];
  }
  final id = left[rng.nextInt(left.length)];
  return (
    id: id,
    cycle: fresh
        ? [id]
        : [
            id,
            for (final c in cycle)
              if (pool.contains(c)) c,
          ],
  );
}

/// The quote for [day]: the one already chosen today, or a new one.
///
/// [fresh] says a new one was chosen and should be remembered.
({String id, List<String> cycle, bool fresh}) quoteForDay({
  required DateTime day,
  required List<String> pool,
  required DateTime? lastDay,
  required String? lastId,
  required List<String> cycle,
  Random? random,
}) {
  final same =
      lastDay != null &&
      lastDay.year == day.year &&
      lastDay.month == day.month &&
      lastDay.day == day.day;
  if (same && lastId != null && pool.contains(lastId)) {
    return (id: lastId, cycle: cycle, fresh: false);
  }
  final n = nextQuote(pool: pool, cycle: cycle, last: lastId, random: random);
  return (id: n.id, cycle: n.cycle, fresh: true);
}
