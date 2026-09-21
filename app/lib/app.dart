import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/theme/app_theme.dart';

class KellerTwelveApp extends ConsumerWidget {
  const KellerTwelveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
