import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup_service.dart';
import '../data/db/database.dart';
import '../data/notification_service.dart';
import '../data/session_service.dart';
import '../data/suggestion_service.dart';
import '../domain/models/prescription.dart';
import '../domain/progression/progression_engine.dart';
import '../features/session/session_controller.dart';
import 'providers.dart';

/// The one database instance. Opened lazily, closed when the app dies.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(ref.watch(databaseProvider)),
);

final runnerControllerProvider = Provider<SessionController>(
  (ref) => SessionController(
    service: ref.watch(sessionServiceProvider),
    db: ref.watch(databaseProvider),
  ),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Stamped into every backup manifest, so a zip found on the PC in a year
/// says which build wrote it.
///
/// MUST match `version:` in pubspec.yaml — `test/version_test.dart` fails the
/// build if the two drift apart, which they already did once.
const appVersion = '0.13.0+13';

final backupServiceProvider = Provider<BackupService>(
  (ref) =>
      BackupService(db: ref.watch(databaseProvider), appVersion: appVersion),
);

/// Bridges the database to the progression engine.
final suggestionServiceProvider = FutureProvider<SuggestionService>((
  ref,
) async {
  final bundle = await ref.watch(bundleProvider.future);
  return SuggestionService(
    db: ref.watch(databaseProvider),
    inventory: bundle.inventory,
    // Which blocks are deloads and tests (never history), and each
    // session's load multiplier.
    programme: bundle.programme,
  );
});

/// What to load next for one prescription, with the plate breakdown and the
/// reason, so the runner can say "27 kg, bar 9 + 5 + 2.5 + 1.25 per side,
/// earned the jump" rather than just a number.
final suggestionProvider =
    FutureProvider.family<LoadSuggestion, ({Prescription p, double mult})>((
      ref,
      args,
    ) async {
      final svc = await ref.watch(suggestionServiceProvider.future);
      return svc.suggest(args.p, blockLoadMultiplier: args.mult);
    });

/// The session that was in progress when the app was last killed, if any.
///
/// Checked on launch: you should never lose a session because the phone
/// decided to reclaim memory between sets.
/// The runner path that opens [session] itself.
///
/// The runner finds a session by its day and its PLANNED date, and assumes
/// today when none is given. A session planned for another day — left open
/// past midnight, or moved — must say its date, or the runner starts a
/// second session for the same day and the first is orphaned.
String sessionRunPath(Session session, {required DateTime today}) {
  final p = session.plannedDate;
  final same =
      p.year == today.year && p.month == today.month && p.day == today.day;
  final iso =
      '${p.year.toString().padLeft(4, '0')}-'
      '${p.month.toString().padLeft(2, '0')}-'
      '${p.day.toString().padLeft(2, '0')}';
  return '/run/${session.weekNo}/${session.dayId}${same ? '' : '?date=$iso'}';
}

final resumableSessionProvider = FutureProvider<Session?>(
  (ref) => ref.watch(sessionServiceProvider).resumable(),
);

/// Completed sessions, newest first.
final historyProvider = FutureProvider<List<Session>>(
  (ref) => ref.watch(databaseProvider).completedSessions(),
);

/// The sets of one session, for the read-only history view.
final sessionSetsProvider = FutureProvider.family<List<SetLog>, int>(
  (ref, sessionId) => ref.watch(databaseProvider).setsForSession(sessionId),
);

/// Working sets from the last time this prescription was trained.
///
/// Shown inline in the runner as "last time: 8, 8, 7 @ 25 kg" — the single
/// most useful number on the screen when you are deciding what to load.
final lastTimeProvider =
    FutureProvider.family<
      List<SetLog>,
      ({String prescriptionId, String exerciseId})
    >((ref, key) async {
      final db = ref.watch(databaseProvider);
      return db.lastSetsForPrescription(key.prescriptionId, key.exerciseId);
    });

/// How many sessions have actually been finished.
///
/// Drives the backup reminder: there is no point nagging about losing data
/// before any exists.
final completedSessionCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return (await db.completedSessions()).length;
});
