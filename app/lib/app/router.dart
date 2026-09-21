import 'package:go_router/go_router.dart';

import '../features/day/day_detail_screen.dart';
import '../features/today/today_screen.dart';
import '../features/week/week_screen.dart';

/// Routes are deep-linkable so Phase 4's calendar can jump straight into a
/// session, and Phase 7's demo handoff can come back to the exact set.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const TodayScreen()),
    GoRoute(path: '/week', builder: (_, _) => const WeekScreen()),
    GoRoute(
      path: '/week/:week/day/:dayId',
      builder: (_, state) => DayDetailScreen(
        weekNo: int.parse(state.pathParameters['week']!),
        dayId: state.pathParameters['dayId']!,
      ),
    ),
  ],
);
