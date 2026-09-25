import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/content/quotes.dart';

/// A quote a day, never the same one twice until every one has been read.
void main() {
  final pool = [for (var i = 0; i < 10; i++) 'q$i'];

  group('the next quote', () {
    test('no quote repeats until every one has been shown', () {
      var cycle = <String>[];
      String? last;
      final seen = <String>[];
      for (var i = 0; i < pool.length; i++) {
        final n = nextQuote(
          pool: pool,
          cycle: cycle,
          last: last,
          random: Random(i),
        );
        seen.add(n.id);
        cycle = n.cycle;
        last = n.id;
      }
      expect(seen.toSet(), pool.toSet());
    });

    test('a new round never opens with the quote that closed the last', () {
      for (var seed = 0; seed < 25; seed++) {
        final n = nextQuote(
          pool: pool,
          cycle: [...pool.reversed],
          last: 'q9',
          random: Random(seed),
        );
        expect(n.id, isNot('q9'));
        expect(n.cycle, [n.id], reason: 'the round starts again');
      }
    });

    test('a quote taken out of the file is forgotten', () {
      final n = nextQuote(
        pool: const ['a', 'b'],
        cycle: const ['gone', 'a'],
        last: 'a',
        random: Random(1),
      );
      expect(n.id, 'b');
    });

    test('a pool of one still gives a quote, and an empty one none', () {
      expect(
        nextQuote(pool: const ['a'], cycle: const ['a'], last: 'a').id,
        'a',
      );
      expect(
        () => nextQuote(pool: const [], cycle: const [], last: null),
        throwsArgumentError,
      );
    });
  });

  group('the quote of the day', () {
    final monday = DateTime(2026, 10, 19);

    test('the same day keeps its quote, however often the app opens', () {
      final d = quoteForDay(
        day: DateTime(2026, 10, 19, 21, 30),
        pool: pool,
        lastDay: monday,
        lastId: 'q3',
        cycle: const ['q3'],
      );
      expect(d.id, 'q3');
      expect(d.fresh, isFalse);
    });

    test('the next day brings a new one and remembers it', () {
      final d = quoteForDay(
        day: DateTime(2026, 10, 20, 6, 45),
        pool: pool,
        lastDay: monday,
        lastId: 'q3',
        cycle: const ['q3'],
        random: Random(7),
      );
      expect(d.id, isNot('q3'));
      expect(d.fresh, isTrue);
      expect(d.cycle, [d.id, 'q3']);
    });

    test('a remembered quote no longer in the file is replaced', () {
      final d = quoteForDay(
        day: monday,
        pool: pool,
        lastDay: monday,
        lastId: 'gone',
        cycle: const ['gone'],
      );
      expect(pool, contains(d.id));
    });
  });

  group('reading the file', () {
    test('parses a quote with its tradition and its source', () {
      final book = QuoteBook.fromJson({
        'quotes': [
          {
            'id': 'q-94-5',
            'tradition': 'quran',
            'text': 'So verily with the hardship there is ease.',
            'attribution': 'Qur’an 94:5',
            'translator': 'Pickthall (1930)',
            'verifiedAt': 'https://example.org/94/5',
          },
        ],
      });
      final q = book.quotes.single;
      expect(q.tradition, QuoteTradition.quran);
      expect(q.attribution, 'Qur’an 94:5');
      expect(q.translator, 'Pickthall (1930)');
      expect(book.byId('q-94-5'), q);
    });

    test('an unknown tradition is dropped, not a crash', () {
      final book = QuoteBook.fromJson({
        'quotes': [
          {
            'id': 'x',
            'tradition': 'motivational-poster',
            'text': 'Never give up.',
            'attribution': 'Anonymous',
          },
        ],
      });
      expect(book.quotes, isEmpty);
    });
  });

  group('the shipped quotes', () {
    final book = QuoteBook.fromJson(
      jsonDecode(File('assets/content/quotes.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    test('enough for a new one every day for seven weeks', () {
      expect(book.quotes.length, greaterThanOrEqualTo(50));
      expect({
        for (final q in book.quotes) q.tradition,
      }, QuoteTradition.values.toSet());
    });

    test('every one says where it is from, and whose English it is', () {
      for (final q in book.quotes) {
        expect(q.translator, isNotNull, reason: q.id);
        expect(q.verifiedAt, startsWith('https://'), reason: q.id);
        switch (q.tradition) {
          case QuoteTradition.quran:
            expect(q.attribution, matches(RegExp(r'^Qur’an \d+:\d+')));
          case QuoteTradition.hadith:
            expect(
              q.attribution,
              matches(RegExp(r'^(Sahih al-Bukhari|Sahih Muslim) \d+$')),
            );
          case QuoteTradition.greek || QuoteTradition.roman:
            expect(q.attribution, contains(','), reason: q.id);
        }
      }
    });
  });
}
