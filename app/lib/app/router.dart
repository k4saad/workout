import 'package:go_router/go_router.dart';

import '../features/body/body_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/cardio/cardio_screen.dart';
import '../features/day/day_detail_screen.dart';
import '../features/history/history_screen.dart';
import '../features/progress/capture_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/session/session_runner_screen.dart';
import '../features/settings/calibration_screen.dart';
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
    GoRoute(
      path: '/run/:week/:dayId',
      builder: (_, state) => SessionRunnerScreen(
        weekNo: int.parse(state.pathParameters['week']!),
        dayId: state.pathParameters['dayId']!,
        retroDate: state.uri.queryParameters['date'] == null
            ? null
            : DateTime.parse(state.uri.queryParameters['date']!),
      ),
    ),
    GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
    GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
    GoRoute(path: '/body', builder: (_, _) => const BodyScreen()),
    GoRoute(path: '/cardio', builder: (_, _) => const CardioScreen()),
    GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
    GoRoute(
      path: '/progress/capture',
      builder: (_, state) => CaptureScreen(
        weekNo: int.tryParse(state.uri.queryParameters['week'] ?? ''),
      ),
    ),
    GoRoute(path: '/gym', builder: (_, _) => const CalibrationScreen()),
  ],
);
