import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/session_providers.dart';
import 'app/settings_providers.dart';
import 'core/theme/app_theme.dart';

class KellerTwelveApp extends ConsumerStatefulWidget {
  const KellerTwelveApp({super.key});

  @override
  ConsumerState<KellerTwelveApp> createState() => _KellerTwelveAppState();
}

class _KellerTwelveAppState extends ConsumerState<KellerTwelveApp> {
  @override
  void initState() {
    super.initState();
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
    );
  }
}
