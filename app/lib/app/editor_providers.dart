import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/programme_editor_service.dart';
import '../domain/models/programme.dart';
import '../domain/programme/programme_editor.dart';
import '../domain/programme/programme_validator.dart';
import '../domain/progression/cycle_seeder.dart';
import 'providers.dart';
import 'session_providers.dart';

const programmeEditor = ProgrammeEditor();

final editorServiceProvider = FutureProvider<ProgrammeEditorService>((
  ref,
) async {
  final repo = ref.watch(programmeRepositoryProvider);
  return ProgrammeEditorService(
    repository: repo,
    db: ref.watch(databaseProvider),
    library: await repo.loadLibrary(),
    inventory: await repo.loadInventory(),
  );
});

/// Problems with the programme as it currently stands.
///
/// Surfaced as a persistent strip in the editor rather than a dialog on save:
/// you want to see that Monday's squat is unloadable while you are still
/// looking at Monday.
final programmeProblemsProvider = FutureProvider<List<Problem>>((ref) async {
  final service = await ref.watch(editorServiceProvider.future);
  final programme = await ref.watch(programmeProvider.future);
  return service.check(programme);
});

/// Applies an edit and refreshes everything downstream.
///
/// Every screen in the app reads the programme through [bundleProvider], so
/// one invalidation here is what makes an edit appear in the runner, the
/// calendar and the week view at once.
class ProgrammeEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<SaveResult> apply(Programme Function(Programme) edit) async {
    final service = await ref.read(editorServiceProvider.future);
    final current = await ref.read(programmeProvider.future);
    final result = await service.save(edit(current));
    _refresh();
    return result;
  }

  Future<SaveResult> applySeed(CycleSeed seed) async {
    final service = await ref.read(editorServiceProvider.future);
    final result = await service.applyNextCycle(seed);
    _refresh();
    return result;
  }

  Future<Programme> applyImport(Programme incoming) async {
    final service = await ref.read(editorServiceProvider.future);
    final saved = await service.applyImport(incoming);
    _refresh();
    return saved;
  }

  Future<Programme> resetToShipped() async {
    final service = await ref.read(editorServiceProvider.future);
    final restored = await service.resetToShipped();
    _refresh();
    return restored;
  }

  /// Everything on the phone was just replaced from a backup zip.
  void refreshAfterRestore() => _refresh();

  void _refresh() {
    ref.read(programmeRepositoryProvider).invalidateProgramme();
    ref
      ..invalidate(programmeProvider)
      ..invalidate(bundleProvider)
      ..invalidate(programmeProblemsProvider);
  }
}

final programmeEditControllerProvider =
    AsyncNotifierProvider<ProgrammeEditController, void>(
      ProgrammeEditController.new,
    );

/// The week-13 proposal, recomputed whenever the programme changes.
final cycleSeedProvider = FutureProvider<CycleSeed>((ref) async {
  final service = await ref.watch(editorServiceProvider.future);
  ref.watch(programmeProvider);
  return service.proposeNextCycle();
});
