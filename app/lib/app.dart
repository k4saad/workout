import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/session_providers.dart';
import 'app/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/launch/launch_gate.dart';

class KellerTwelveApp extends ConsumerStatefulWidget {
  const KellerTwelveApp({super.key});

  @override
  ConsumerState<KellerTwelveApp> createState() => _KellerTwelveAppState();
}

class _KellerTwelveAppState extends ConsumerState<KellerTwelveApp> {
  late final AppLifecycleListener _life;
  Timer? _midnight;

  /// Keeps "today" true while the app lives in memory across midnight: on
  /// every return to the app, and at midnight if it is open then.
  void _rollOver() {
    ref.read(todayProvider.notifier).refresh();
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      nextMidnight(now).difference(now) + const Duration(seconds: 1),
      _rollOver,
    );
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _life.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _rollOver);
    _rollOver();
    // Relay the next fortnight of session reminders against the programme as
    // it stands today. An edit made last week must not leave a notification
    // announcing a session that no longer exists.
    //
    // Every failure here is swallowed on purpose: a missing nudge is a minor
    // annoyance, and an app that will not open is not.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(notificationServiceProvider).init();
        await ref.read(preferencesProvider.notifier).refreshSchedule();
      } catch (_) {
        // Deliberately silent.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'The Keller Twelve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      // Dark-first and dark-only: this app is used in a basement.
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      // Over the router, not a route: deep links and a resumed session land
      // where they would have without it.
      builder: (context, child) => LaunchGate(child: child!),
    );
  }
}
