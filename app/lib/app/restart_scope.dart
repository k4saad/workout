import 'package:flutter/widgets.dart';

/// Rebuilds everything beneath it from scratch — a new provider container,
/// a new database connection, fresh caches — as if the app had been closed
/// and opened again.
///
/// For the one moment that needs it: a restore replaces the database, the
/// programme, the equipment and the preferences underneath a running app,
/// and a dozen cached reads would otherwise go on showing what was there
/// before until the next cold start.
class RestartScope extends StatefulWidget {
  const RestartScope({super.key, required this.builder});

  /// Builds the app; the key changes on every restart.
  final Widget Function(Key key) builder;

  /// Restarts the nearest scope. False when there is none (a test that
  /// pumps a screen on its own), so the caller can fall back.
  static bool restart(BuildContext context) {
    final state = context.findAncestorStateOfType<_RestartScopeState>();
    state?._restart();
    return state != null;
  }

  @override
  State<RestartScope> createState() => _RestartScopeState();
}

class _RestartScopeState extends State<RestartScope> {
  Key _key = UniqueKey();

  void _restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) => widget.builder(_key);
}
