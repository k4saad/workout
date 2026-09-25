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
          icon: Icons.calendar_view_week_outlined,
          active: Icons.calendar_view_week,
        ),
        (
          label: 'Fuel',
          icon: Icons.restaurant_outlined,
          active: Icons.restaurant,
        ),
        (
          label: 'Progress',
          icon: Icons.insights_outlined,
          active: Icons.insights,
        ),
        (
          label: 'More',
          icon: Icons.grid_view_outlined,
          active: Icons.grid_view,
        ),
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
            border: Border(top: BorderSide(color: AppTheme.outlineSoft)),
          ),
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            // Tapping the tab you are already on pops that tab back to its
            // root — the standard "take me back to the top" gesture.
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              shell.goBranch(i, initialLocation: i == shell.currentIndex);
            },
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

/// Every tab's navigator, side by side: swipe sideways on a tab's own
/// screen for the next tab, tap the bar to jump.
///
/// A swipe follows the finger — the neighbouring tab slides in under it —
/// and commits past half way, exactly like the bar would. It only works on a
/// tab's ROOT screen: a drill-down (a lift, a run, the library) keeps its
/// sideways gestures for itself, and back walks its stack as before.
/// Anything inside a tab that drags sideways itself — the photo wipe, a
/// slider, a horizontal list — wins the gesture, because the innermost
/// recognizer claims it first.
///
/// go_router hands each branch in a keep-alive proxy, so a tab scrolled out
/// of view keeps its navigator and its place. Only the tabs on screen tick;
/// the rest are paused. Finders in tests do not see a tab that is out of
/// view, as with the old stacked container.
class SwipeBranchContainer extends StatefulWidget {
  const SwipeBranchContainer({
    super.key,
    required this.shell,
    required this.children,
  });

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  State<SwipeBranchContainer> createState() => _SwipeBranchContainerState();
}

class _SwipeBranchContainerState extends State<SwipeBranchContainer>
    with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.shell.currentIndex,
  )..addListener(_track);

  /// A tap on the bar cuts, then fades the tab in, as it always has; a swipe
  /// needs no fade — the tab is already there.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: AppMotion.curve,
  );

  /// The tabs with any part on screen: the only ones whose tickers run.
  late Set<int> _onScreen = {widget.shell.currentIndex};

  int get _index => widget.shell.currentIndex;

  /// On a tab's root screen, not somewhere drilled into it.
  bool get _atRoot {
    final root = widget.shell.route.branches[_index].defaultRoute?.path;
    final here = widget.shell.shellRouteContext.routerState.uri.path;
    return root == null || here == root;
  }

  void _track() {
    final page = _pages.page;
    if (page == null) return;
    final now = {page.floor(), page.ceil()};
    if (now.length != _onScreen.length || !now.containsAll(_onScreen)) {
      setState(() => _onScreen = now);
    }
  }

  @override
  void didUpdateWidget(SwipeBranchContainer old) {
    super.didUpdateWidget(old);
    if (!_pages.hasClients) return;
    final shown = (_pages.page ?? _index.toDouble()).round();
    if (shown == _index) return; // a swipe: already there
    // The bar was tapped. Jump, and fade the tab in. (On-screen first, so
    // the jump's own page listener finds nothing to rebuild.)
    _onScreen = {_index};
    _pages.jumpToPage(_index);
    if (AppMotion.reduced(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pages
      ..removeListener(_track)
      ..dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: PageView(
      controller: _pages,
      physics: _atRoot
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (i) {
        if (i == _index) return;
        HapticFeedback.selectionClick();
        widget.shell.goBranch(i);
      },
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(enabled: _onScreen.contains(i), child: widget.children[i]),
      ],
    ),
  );
}
