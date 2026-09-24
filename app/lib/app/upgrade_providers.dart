import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/programme_repository.dart';
import 'providers.dart';

/// The shipped-revision upgrade the athlete has not dismissed yet, if any.
///
/// Read once the bundle has loaded — loading is what runs the upgrade — so
/// this never does file I/O of its own.
class UpgradeNoticeNotifier extends AsyncNotifier<ProgrammeUpgrade?> {
  @override
  Future<ProgrammeUpgrade?> build() async {
    await ref.watch(bundleProvider.future);
    return ref.read(programmeRepositoryProvider).lastUpgrade;
  }

  /// Seen. It does not come back, on this launch or the next.
  Future<void> dismiss() async {
    state = const AsyncData(null);
    await ref.read(programmeRepositoryProvider).dismissUpgradeNotice();
  }
}

final upgradeNoticeProvider =
    AsyncNotifierProvider<UpgradeNoticeNotifier, ProgrammeUpgrade?>(
      UpgradeNoticeNotifier.new,
    );
