import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../domain/models/exercise.dart';
import 'providers.dart';
import 'session_providers.dart';

/// The exercise library, for screens that do not need the whole bundle.
final libraryProvider = FutureProvider<ExerciseLibrary>(
  (ref) => ref.watch(programmeRepositoryProvider).loadLibrary(),
);

/// Your own filmed sets for one movement, newest first.
final clipsProvider = FutureProvider.family<List<FormClip>, String>(
  (ref, exerciseId) => ref.watch(databaseProvider).clipsForExercise(exerciseId),
);
