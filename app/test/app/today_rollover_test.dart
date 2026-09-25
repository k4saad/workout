import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/providers.dart';

/// Android keeps the app in memory for days. Opened the next morning, it
/// must be the next morning.
void main() {
  test('after midnight, today moves on', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final first = c.read(todayProvider);
    final tomorrow = DateTime(first.year, first.month, first.day + 1, 6, 30);

    c.read(todayProvider.notifier).refresh(() => tomorrow);
    expect(
      c.read(todayProvider),
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    );
  });

  test('the same day, nothing changes and nothing rebuilds', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final first = c.read(todayProvider);
    var rebuilt = 0;
    c.listen(todayProvider, (_, _) => rebuilt++);

    c
        .read(todayProvider.notifier)
        .refresh(() => DateTime(first.year, first.month, first.day, 23, 59));
    expect(c.read(todayProvider), first);
    expect(rebuilt, 0);
  });

  test('a date pinned by hand stays pinned', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(todayProvider.notifier).set(DateTime(2026, 10, 19));
    c.read(todayProvider.notifier).refresh(() => DateTime(2026, 12, 1));
    expect(c.read(todayProvider), DateTime(2026, 10, 19));
  });

  test('the next midnight is counted in calendar days, not 24 hours', () {
    // The night the clocks go back in Germany: 25 October 2026.
    final at = DateTime(2026, 10, 24, 22);
    expect(nextMidnight(at), DateTime(2026, 10, 25));
    expect(nextMidnight(DateTime(2026, 12, 31, 23, 59)), DateTime(2027));
  });
}
