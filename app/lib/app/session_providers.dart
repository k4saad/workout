import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup_service.dart';
import '../data/db/database.dart';
import '../data/notification_service.dart';
import '../data/session_service.dart';
import '../features/session/session_controller.dart';

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

const appVersion = '0.2.0+2';

final backupServiceProvider = Provider<BackupService>(
  (ref) =>
      BackupService(db: ref.watch(databaseProvider), appVersion: appVersion),
);

/// The session that was in progress when the app was last killed, if any.
///
/// Checked on launch: you should never lose a session because the phone
/// decided to reclaim memory between sets.
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
final lastTimeProvider = FutureProvider.family<List<SetLog>, String>((
  ref,
  prescriptionId,
) async {
  final db = ref.watch(databaseProvider);
  final own = await db.lastSetsForPrescription(prescriptionId);
  return own;
});
