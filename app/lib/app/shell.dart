import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// The frame every screen lives inside.
///
/// Two things this fixes, both reported from the basement:
///
///  * **Back used to quit the app.** Every screen navigated with `context.go`,
///    which REPLACES the stack, so there was never anything to go back to.
///    Each tab now owns its own navigator, drill-downs `push` onto it, and
///    back walks up that stack. Back on a tab root returns to Today; back on
///    Today asks before it quits.
///  * **Everything was in the top bar.** On a phone held one-handed with a
///    bar in the other hand, the top of the screen is the furthest place from
///    your thumb. The five things you actually reach for now live at the
///    bottom.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const destinations =
      <({String label, IconData icon, IconData active})>[
        (label: 'Today', icon: Icons.today_outlined, active: Icons.today),
        (
          label: 'Week',
          icon: Icons.view_week_outlined,
          active: Icons.view_week,
        ),
        (
          label: 'Numbers',
          icon: Icons.insights_outlined,
          active: Icons.insights,
        ),
        (
          label: 'Body',
          icon: Icons.accessibility_new_outlined,
          active: Icons.accessibility_new,
        ),
        (label: 'More', icon: Icons.menu, active: Icons.menu_open),
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The tab's own navigator gets first refusal; this only runs when that
      // stack is already at its root.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (shell.currentIndex != 0) {
          shell.goBranch(0);
          return;
        }
        final leave = await _confirmExit(context);
        // SystemNavigator.pop, not Navigator.pop: there is nothing underneath
        // the root route, and popping it does nothing at all.
        if (leave) await SystemNavigator.pop();
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.outline)),
          ),
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            // Tapping the tab you are already on pops that tab back to its
            // root — the standard "take me back to the top" gesture.
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.active),
                  label: d.label,
                  tooltip: d.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Close the app?'),
        content: const Text(
          'Nothing is lost — every set is saved the moment you log it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
