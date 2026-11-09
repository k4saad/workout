import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/body/body_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/cardio/cardio_screen.dart';
import '../features/day/day_detail_screen.dart';
import '../features/editor/cycle_seed_screen.dart';
import '../features/editor/programme_editor_screen.dart';
import '../features/exercises/exercise_detail_screen.dart';
import '../features/exercises/exercise_library_screen.dart';
import '../features/fuel/fuel_screen.dart';
import '../features/history/history_screen.dart';
import '../features/more/more_screen.dart';
import '../features/progress/capture_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/progress/shoot_viewer_screen.dart';
import '../features/progress_hub/progress_hub_screen.dart';
import '../features/runs/hikes_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/planner/timetable_screen.dart';
import '../features/runs/live_run_screen.dart';
import '../features/runs/runs_screen.dart';
import '../features/session/session_runner_screen.dart';
import '../features/settings/calibration_screen.dart';
import '../features/settings/programme_file_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/lift_detail_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/today/today_screen.dart';
import '../features/week/week_screen.dart';
import 'shell.dart';

/// Five tabs — Today · Week · Fuel · Progress · More — each with its own
/// navigator, plus the full-screen routes that live outside the shell.
///
/// v3 gave Fuel a tab of its own (meals are logged six times a day; that is
/// the most-reached thing in the app) and folded the old Numbers and Body
/// tabs into one Progress hub: body, photos, lifts and runs.
///
/// The session runner and the camera sit OUTSIDE the shell deliberately: mid
/// set, a tab bar is four ways to lose your place, and the capture screen
/// needs every pixel for the ghost overlay.
///
/// Routes stay deep-linkable so the calendar can jump straight into a session
/// and the demo handoff can come back to the exact set.
///
/// Built by a function rather than held as one global: a GoRouter carries the
/// per-branch navigator stacks, so a shared instance leaks a tab's position
/// from one widget test into the next.
GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute(
        builder: (_, _, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (_, shell, children) =>
            SwipeBranchContainer(shell: shell, children: children),
        branches: [
          // ---- 1. Today ----------------------------------------------------
          StatefulShellBranch(
            // Built ahead, so a swipe slides in a tab, not a blank.
            preload: true,
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (_, _) => const HistoryScreen(),
                  ),
                ],
              ),
            ],
          ),

          // ---- 2. Week -----------------------------------------------------
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/week',
                builder: (_, _) => const WeekScreen(),
                routes: [
                  GoRoute(
                    path: 'calendar',
                    builder: (_, _) => const CalendarScreen(),
                  ),
                  GoRoute(
                    path: 'planner',
                    builder: (_, state) => PlannerScreen(
                      initialDate: DateTime.tryParse(
                        state.uri.queryParameters['date'] ?? '',
                      ),
                    ),
                    routes: [
                      // His week, to change: nested, so back is the planner.
                      GoRoute(
                        path: 'timetable',
                        builder: (_, state) => TimetableScreen(
                          openBlock: state.uri.queryParameters['block'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':week/day/:dayId',
                    builder: (_, state) => DayDetailScreen(
                      weekNo: int.parse(state.pathParameters['week']!),
                      dayId: state.pathParameters['dayId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ---- 3. Fuel -----------------------------------------------------
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(path: '/fuel', builder: (_, _) => const FuelScreen()),
            ],
          ),

          // ---- 4. Progress -------------------------------------------------
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/progress',
                builder: (_, _) => const ProgressHubScreen(),
                routes: [
                  GoRoute(path: 'body', builder: (_, _) => const BodyScreen()),
                  GoRoute(
                    path: 'photos',
                    builder: (_, _) => const ProgressScreen(),
                    routes: [
                      GoRoute(
                        path: ':shootId',
                        builder: (_, state) => ShootViewerScreen(
                          shootId: state.pathParameters['shootId']!,
                          poseId: state.uri.queryParameters['pose'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'runs',
                    builder: (_, _) => const RunsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => RunDetailScreen(
                          runId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'hikes',
                    builder: (_, _) => const HikesScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => RunDetailScreen(
                          runId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'lifts',
                    builder: (_, _) => const StatsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => LiftDetailScreen(
                          exerciseId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ---- 5. More -----------------------------------------------------
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'exercises',
                    builder: (_, _) => const ExerciseLibraryScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => ExerciseDetailScreen(
                          exerciseId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'cardio',
                    builder: (_, _) => const CardioScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'gym',
                        builder: (_, _) => const CalibrationScreen(),
                      ),
                      GoRoute(
                        path: 'programme',
                        builder: (_, _) => const ProgrammeEditorScreen(),
                      ),
                      GoRoute(
                        path: 'files',
                        builder: (_, _) => const ProgrammeFileScreen(),
                      ),
                      GoRoute(
                        path: 'next-cycle',
                        builder: (_, _) => const CycleSeedScreen(),
                      ),
                      GoRoute(
                        path: 'timetable',
                        builder: (_, _) => const TimetableScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ---- Full screen, no tab bar -----------------------------------------
      GoRoute(
        path: '/run/:week/:dayId',
        parentNavigatorKey: rootKey,
        builder: (_, state) => SessionRunnerScreen(
          weekNo: int.parse(state.pathParameters['week']!),
          dayId: state.pathParameters['dayId']!,
          retroDate: state.uri.queryParameters['date'] == null
              ? null
              : DateTime.parse(state.uri.queryParameters['date']!),
        ),
      ),
      // The live run tracker: a programme run passes its RunLaunch as
      // `extra`; a free run passes nothing.
      GoRoute(
        path: '/track',
        parentNavigatorKey: rootKey,
        builder: (_, state) => LiveRunScreen(
          launch: state.extra is RunLaunch
              ? state.extra! as RunLaunch
              : const RunLaunch(),
        ),
      ),
      GoRoute(
        path: '/capture',
        parentNavigatorKey: rootKey,
        builder: (_, state) => CaptureScreen(
          weekNo: int.tryParse(state.uri.queryParameters['week'] ?? ''),
        ),
      ),
    ],
  );
}

/// The app's router. One per process.
final appRouter = buildRouter();
