import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/restart_scope.dart';

/// After a restore the app restarts in place: every provider is built
/// again, and the old ones are disposed — which is what closes the old
/// database connection.
void main() {
  var built = 0;
  var disposed = 0;
  final counter = NotifierProvider<_Counter, int>(_Counter.new);
  final resource = Provider<int>((ref) {
    built++;
    ref.onDispose(() => disposed++);
    return built;
  });

  testWidgets('a restart builds every provider afresh', (tester) async {
    await tester.pumpWidget(
      RestartScope(
        builder: (key) => ProviderScope(
          key: key,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  Text('count ${ref.watch(counter)}'),
                  Text('resource ${ref.watch(resource)}'),
                  TextButton(
                    onPressed: () => ref.read(counter.notifier).bump(),
                    child: const Text('bump'),
                  ),
                  TextButton(
                    onPressed: () => RestartScope.restart(context),
                    child: const Text('restart'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bump'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
    expect(find.text('resource 1'), findsOneWidget);

    await tester.tap(find.text('restart'));
    await tester.pump();
    expect(find.text('count 0'), findsOneWidget, reason: 'state is fresh');
    expect(find.text('resource 2'), findsOneWidget, reason: 'rebuilt');
    expect(disposed, 1, reason: 'the old one was closed');
  });

  testWidgets('with no scope above, restart says so', (tester) async {
    late bool restarted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => restarted = RestartScope.restart(context),
            child: const Text('restart'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('restart'));
    expect(restarted, isFalse);
  });
}

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
