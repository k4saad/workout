import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/exercise_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/models/exercise.dart';
import 'exercise_detail_screen.dart';
import 'widgets/motion_demo.dart';

/// Every movement in the programme, searchable.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  String? _pattern;
  String? _muscle;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider).asData?.value;

    if (library == null) {
      return const Scaffold(body: SkeletonPage());
    }

    var results = library.search(_search.text).toList();
    if (_pattern != null) {
      results = results.where((e) => e.pattern == _pattern).toList();
    }
    if (_muscle != null) {
      results = results
          .where((e) => e.primaryMuscles.contains(_muscle))
          .toList();
    }
    results.sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: AppTheme.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final p in library.allPatterns)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(p),
                      selected: _pattern == p,
                      onSelected: (on) =>
                          setState(() => _pattern = on ? p : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final m in library.allMuscles)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(m),
                      selected: _muscle == m,
                      onSelected: (on) =>
                          setState(() => _muscle = on ? m : null),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '${results.length} of ${library.length}',
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
                const Spacer(),
                if (_pattern != null || _muscle != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _pattern = null;
                      _muscle = null;
                    }),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'Nothing matches that.',
                      style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _Row(exercise: results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: _Thumb(exerciseId: exercise.id),
      title: Text(exercise.name, style: t.titleMedium),
      subtitle: Text(
        exercise.primaryMuscles.join(', '),
        style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
      ),
      trailing: exercise.isSoloRisk
          ? const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: AppTheme.warn,
            )
          : const Icon(Icons.chevron_right, color: AppTheme.textDim),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseDetailScreen(exerciseId: exercise.id),
        ),
      ),
    );
  }
}

/// The movement at its most telling moment, not animated: seventy-eight
/// figures moving at once in a list is noise, not information.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Hero(
        tag: 'demo-$exerciseId',
        child: ExerciseDemo(
          exerciseId: exerciseId,
          animate: false,
          padding: 3,
          tight: true,
        ),
      ),
    );
  }
}
