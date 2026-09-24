import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/inventory.dart';
import '../../domain/models/programme.dart';
import '../../domain/plates/kit_summary.dart';
import '../../domain/plates/lattice.dart';
import '../../domain/plates/plate_solver.dart';
import '../common/widgets.dart';

/// Your equipment: the kit every suggested load is built from.
///
/// The bars and plates are the definitive kit (collars included), read from
/// the inventory. The screen says what they reach, which small plates make
/// the whole-kilogram steps, and what each week-12 target puts on the bar —
/// all computed from the inventory and the programme, none of it typed here.
/// Editing stays possible for kit that really changes.
///
/// (Named CalibrationScreen for the route; there is nothing left to
/// calibrate.)
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  Inventory? _draft;
  bool _editing = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bundleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your equipment'),
        actions: [
          if (!_editing)
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit'),
            )
          else if (_draft == null)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Done'),
            )
          else ...[
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _draft = null;
                      _editing = false;
                    }),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const SkeletonPage(cards: 4),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (b) {
          final inv = _draft ?? b.inventory;
          final lattice = _draft == null ? b.lattice : Lattice(inv);
          final reaches = [
            for (final m in KitSummary.implements)
              KitSummary.reach(inv, m, lattice: lattice),
          ];
          final small = KitSummary.wholeKgPlates(inv);
          final targets = _targets(b.programme, b.library, inv);

          // Only what is on screen at open cascades in. A card built later,
          // as the list scrolls, just appears: a staggered delay there would
          // read as lag.
          var i = 0;
          Widget arrive(Widget w) =>
              i < 3 ? FadeSlideIn(index: i++, child: w) : w;

          return ListView(
            padding: Gap.pagePadding,
            children: [
              arrive(_KitHero(inventory: inv, reaches: reaches)),
              if (_editing) ...[
                Gap.m,
                const ToneBanner(
                  tone: Tone.info,
                  icon: Icons.tune,
                  title: 'Change only what you own',
                  body:
                      'Every load the app suggests moves with these numbers. '
                      'Bar weights include both collars.',
                ),
              ],
              const SectionHeader('Bars'),
              arrive(
                _BarsCard(
                  inventory: inv,
                  editing: _editing,
                  onChanged: (next) => _updateBar(inv, next),
                ),
              ),
              const SectionHeader('Plates'),
              arrive(
                _PlatesCard(
                  inventory: inv,
                  small: small,
                  editing: _editing,
                  onChanged: (next) => _updatePlate(inv, next),
                ),
              ),
              const SectionHeader('What it loads'),
              arrive(_ReachCard(reaches: reaches)),
              if (targets.isNotEmpty) ...[
                const SectionHeader('Loading your week-12 targets'),
                arrive(_TargetsCard(targets: targets)),
              ],
              if (inv.fixedDumbbells.isNotEmpty ||
                  inv.kettlebells.isNotEmpty) ...[
                const SectionHeader('Also in the kit'),
                arrive(_ExtrasCard(inventory: inv)),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Every strength target with a load, on the implement its exercise uses,
  /// solved into plates. Straight from the programme: add a target there and
  /// it appears here.
  static List<_Target> _targets(
    Programme programme,
    ExerciseLibrary library,
    Inventory inventory,
  ) {
    final solver = PlateSolver(inventory);
    return [
      for (final t in programme.strengthTargets)
        if (t.week12Kg != null && t.week12Kg!.isNotEmpty)
          if (library[t.exerciseId] case final ex?)
            if (ex.defaultLoadMode.isPlateLoaded)
              _Target(
                exerciseId: t.exerciseId,
                name: ex.name,
                reps: t.reps,
                solution: solver.solve(t.week12Kg!.last, ex.defaultLoadMode),
              ),
    ];
  }

  void _updateBar(Inventory inv, Bar next) {
    setState(() {
      _draft = inv.copyWith(
        bars: [
          for (final b in inv.bars)
            if (b.id == next.id) next else b,
        ],
      );
    });
  }

  void _updatePlate(Inventory inv, PlateStock next) {
    setState(() {
      _draft = inv.copyWith(
        plates: [
          for (final p in inv.plates)
            if (p.weightKg == next.weightKg) next else p,
        ],
      );
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    await ref.read(programmeRepositoryProvider).saveInventory(draft);
    ref.invalidate(inventoryProvider);
    ref.invalidate(bundleProvider);
    if (!mounted) return;
    setState(() {
      _draft = null;
      _editing = false;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved. Every load in the app now comes from this kit.'),
      ),
    );
  }
}

class _Target {
  const _Target({
    required this.exerciseId,
    required this.name,
    required this.reps,
    required this.solution,
  });

  final String exerciseId;
  final String name;
  final int reps;
  final PlateSolution solution;
}

String _fmt(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

int _decimals(double v) =>
    v == v.roundToDouble() ? 0 : (v * 10 == (v * 10).roundToDouble() ? 1 : 2);

String _implementLabel(LoadMode mode) => switch (mode) {
  LoadMode.barbell => 'Barbell',
  LoadMode.ezBar => 'EZ bar',
  LoadMode.dumbbellPair => 'Dumbbells, as a pair',
  LoadMode.dumbbellSingle => 'One dumbbell',
  _ => mode.name,
};

/// The headline: what this kit means, in one line and three numbers.
class _KitHero extends StatelessWidget {
  const _KitHero({required this.inventory, required this.reaches});

  final Inventory inventory;
  final List<ImplementReach> reaches;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final every = reaches.every((r) => r.everyWholeKg);
    final step = reaches.map((r) => r.largestStepKg).fold(0.0, math.max);
    final barbell = reaches.firstWhere(
      (r) => r.mode == LoadMode.barbell,
      orElse: () => reaches.first,
    );
    const tint = Color(0xE6FFFFFF);
    const faint = Color(0xB3FFFFFF);
    return AppCard(
      hero: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE KIT', style: AppTheme.overline.copyWith(color: faint)),
          Gap.s,
          Text(
            every
                ? 'Every whole kilogram, on every bar'
                : 'Steps of up to ${_fmt(step)} kg',
            style: t.headlineSmall!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap.s,
          Text(
            inventory.collarWeightKg == 0
                ? 'Weights include both collars. Every load the app suggests '
                      'is built from this list.'
                : 'Collars add ${_fmt(inventory.collarWeightKg)} kg. Every '
                      'load the app suggests is built from this list.',
            style: t.bodyMedium!.copyWith(color: tint),
          ),
          Gap.l,
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Bar',
                  value: barbell.baseKg,
                  decimals: _decimals(barbell.baseKg),
                  unit: 'kg',
                  color: Colors.white,
                  labelColor: faint,
                  unitColor: Colors.white,
                  size: 30,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Step',
                  value: step,
                  decimals: _decimals(step),
                  unit: 'kg',
                  color: Colors.white,
                  labelColor: faint,
                  unitColor: Colors.white,
                  size: 30,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Heaviest',
                  value: barbell.maxKg,
                  decimals: _decimals(barbell.maxKg),
                  unit: 'kg',
                  color: Colors.white,
                  labelColor: faint,
                  unitColor: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarsCard extends StatelessWidget {
  const _BarsCard({
    required this.inventory,
    required this.editing,
    required this.onChanged,
  });

  final Inventory inventory;
  final bool editing;
  final ValueChanged<Bar> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final collars = inventory.collarWeightKg == 0
        ? 'collars included'
        : 'plus ${_fmt(inventory.collarWeightKg)} kg of collars';
    final bars = inventory.bars;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 14, 6),
      child: Column(
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.outlineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bars[i].name, style: t.titleMedium),
                        Text(
                          collars,
                          style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                        ),
                      ],
                    ),
                  ),
                  if (editing)
                    _NumberStepper(
                      keyPrefix: 'bar-${bars[i].id}',
                      label: bars[i].name,
                      value: bars[i].weightKg,
                      step: 0.5,
                      min: 0.5,
                      suffix: 'kg',
                      onChanged: (v) => onChanged(
                        bars[i].copyWith(weightKg: v, measured: true),
                      ),
                    )
                  else
                    _Kg(bars[i].weightKg, size: 26),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A number in the display face with a dim unit after it.
class _Kg extends StatelessWidget {
  const _Kg(this.kg, {this.size = 22});

  final double kg;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(_fmt(kg), style: AppTheme.numeric(size)),
      const SizedBox(width: 3),
      Text(
        'kg',
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(color: AppTheme.textDim),
      ),
    ],
  );
}

class _PlatesCard extends StatelessWidget {
  const _PlatesCard({
    required this.inventory,
    required this.small,
    required this.editing,
    required this.onChanged,
  });

  final Inventory inventory;
  final List<PlateStock> small;
  final bool editing;
  final ValueChanged<PlateStock> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final plates = [...inventory.plates]
      ..sort((a, b) => b.weightKg.compareTo(a.weightKg));
    if (plates.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.circle_outlined,
          title: 'No plates yet',
          body: 'Tap Edit to add the plates you own.',
        ),
      );
    }
    final heaviest = plates.first.weightKg;
    final isSmall = {for (final p in small) p.weightKg};

    if (editing) {
      return AppCard(
        padding: const EdgeInsets.fromLTRB(18, 6, 14, 6),
        child: Column(
          children: [
            for (var i = 0; i < plates.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppTheme.outlineSoft),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Center(
                        child: _PlateDisc(
                          kg: plates[i].weightKg,
                          heaviest: heaviest,
                          marked: isSmall.contains(plates[i].weightKg),
                          size: 34,
                        ),
                      ),
                    ),
                    Gap.m,
                    if (isSmall.contains(plates[i].weightKg)) ...[
                      const Icon(
                        Icons.diamond,
                        size: 13,
                        color: AppTheme.crimson,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Kg(plates[i].weightKg, size: 20),
                      ),
                    ),
                    _NumberStepper(
                      keyPrefix: 'plate-${plates[i].weightKg}',
                      label: '${_fmt(plates[i].weightKg)} kg plates',
                      value: plates[i].count.toDouble(),
                      step: 1,
                      min: 0,
                      suffix: '',
                      onChanged: (v) =>
                          onChanged(plates[i].copyWith(count: v.round())),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final bore = switch (plates.first.bore) {
      'olympic' => '50 mm',
      _ => '30 mm',
    };
    final smallNote = small.isEmpty ? null : _smallNote(inventory, small);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const perRow = 4;
              const gap = 8.0;
              final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
              return Wrap(
                spacing: gap,
                runSpacing: 16,
                children: [
                  for (final p in plates)
                    SizedBox(
                      key: ValueKey('plate-${p.weightKg}'),
                      width: w,
                      child: _PlateTile(
                        plate: p,
                        heaviest: heaviest,
                        marked: isSmall.contains(p.weightKg),
                      ),
                    ),
                ],
              );
            },
          ),
          Gap.m,
          Text(
            'Cast iron, $bore bore. The count is every plate you own, both '
            'sides together.',
            style: t.bodySmall!.copyWith(color: AppTheme.textDim),
          ),
          if (smallNote != null) ...[
            Gap.m,
            const Divider(height: 1, color: AppTheme.outlineSoft),
            Gap.m,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.diamond_outlined,
                    size: 18,
                    color: AppTheme.crimson,
                  ),
                ),
                Gap.s,
                Expanded(child: Text(smallNote, style: t.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "1 kg × 4 and 0.5 kg × 8 are the small plates …" — every number in it
  /// computed from the kit.
  static String _smallNote(Inventory inventory, List<PlateStock> small) {
    final list = small.map((p) => '${_fmt(p.weightKg)} kg × ${p.count}');
    final names = list.length == 1
        ? list.first
        : '${list.take(list.length - 1).join(', ')} and ${list.last}';
    final smallSizes = {for (final p in small) p.weightKg};
    final without = inventory.copyWith(
      plates: [
        for (final p in inventory.plates)
          if (!smallSizes.contains(p.weightKg)) p,
      ],
    );
    final reach = KitSummary.reach(without, LoadMode.barbell);
    final smallest = without.smallestPlateKg;
    final consequence = smallest == null
        ? ''
        : ' Without them the smallest plate is ${_fmt(smallest)} kg, and '
              'the bar jumps ${_fmt(reach.largestStepKg)} kg at a time.';
    final verb = small.length == 1
        ? 'is the small plate'
        : 'are the small '
              'plates';
    return '$names $verb that make every whole kilogram. Get them if they '
        'are not on the rack yet.$consequence';
  }
}

class _PlateTile extends StatelessWidget {
  const _PlateTile({
    required this.plate,
    required this.heaviest,
    required this.marked,
  });

  final PlateStock plate;
  final double heaviest;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: Center(
            child: _PlateDisc(
              kg: plate.weightKg,
              heaviest: heaviest,
              marked: marked,
            ),
          ),
        ),
        Gap.s,
        // Shrinks rather than overflows at a large system text size.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (marked) ...[
                const Icon(Icons.diamond, size: 13, color: AppTheme.crimson),
                const SizedBox(width: 3),
              ],
              _Kg(plate.weightKg, size: 20),
            ],
          ),
        ),
        Text(
          '× ${plate.count}',
          style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }
}

/// A plate seen face on: size follows weight, a raised rim, the bore in the
/// middle. A small plate gets a crimson edge here and a diamond by its
/// label, so the mark never rests on colour alone.
class _PlateDisc extends StatelessWidget {
  const _PlateDisc({
    required this.kg,
    required this.heaviest,
    required this.marked,
    this.size = 58,
  });

  final double kg;
  final double heaviest;
  final bool marked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frac = heaviest <= 0 ? 1.0 : math.sqrt(kg / heaviest);
    final d = size * (0.38 + 0.62 * frac.clamp(0.0, 1.0));
    return SizedBox.square(
      dimension: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF2E2E36),
                  Color(0xFF202026),
                  Color(0xFF3A3A43),
                  Color(0xFF26262D),
                ],
                stops: [0.0, 0.72, 0.86, 1.0],
              ),
              border: Border.all(
                color: marked ? AppTheme.crimson : AppTheme.outline,
                width: marked ? 1.6 : 1,
              ),
            ),
          ),
          Container(
            width: math.max(5, d * 0.2),
            height: math.max(5, d * 0.2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReachCard extends StatelessWidget {
  const _ReachCard({required this.reaches});

  final List<ImplementReach> reaches;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String sub(ImplementReach r) {
      final each = r.mode == LoadMode.dumbbellPair ? ' · per dumbbell' : '';
      if (r.everyWholeKg) return 'Every whole kilogram$each';
      if (r.maxKg <= r.baseKg) return 'Bare only — no plates$each';
      if (r.wholeKgToKg > r.baseKg) {
        return 'Every kilogram to ${_fmt(r.wholeKgToKg)}, then steps of up '
            'to ${_fmt(r.largestStepKg)} kg$each';
      }
      return 'Steps of up to ${_fmt(r.largestStepKg)} kg$each';
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < reaches.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.outlineSoft),
            Padding(
              key: ValueKey('reach-${reaches[i].mode.name}'),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _implementLabel(reaches[i].mode),
                          style: t.titleMedium,
                        ),
                        Text(
                          sub(reaches[i]),
                          style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                        ),
                      ],
                    ),
                  ),
                  Gap.s,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${_fmt(reaches[i].baseKg)}–'
                        '${_fmt(reaches[i].maxKg)}',
                        style: AppTheme.numeric(20),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'kg',
                        style: t.labelLarge!.copyWith(color: AppTheme.textDim),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.targets});

  final List<_Target> targets;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final heaviest = targets
        .expand((x) => x.solution.perSide)
        .map((p) => p.kg)
        .fold(0.0, math.max);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One side of the bar on test day. These are floors the '
            'programme\'s own steps reach, not goals.',
            style: t.bodySmall!.copyWith(color: AppTheme.textDim),
          ),
          Gap.s,
          for (var i = 0; i < targets.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.outlineSoft),
            _TargetRow(target: targets[i], heaviest: heaviest),
          ],
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.target, required this.heaviest});

  final _Target target;
  final double heaviest;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = target.solution;
    final plates = [
      for (final pc in s.perSide)
        for (var n = 0; n < pc.count; n++) pc.kg,
    ];
    final perSide = s.perSide.map((p) => p.toString()).join(' + ');
    return Padding(
      key: ValueKey('target-${target.exerciseId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(target.name, style: t.titleMedium)),
              Text(_fmt(s.achievableKg), style: AppTheme.numeric(22)),
              const SizedBox(width: 3),
              Text(
                'kg × ${target.reps}',
                style: t.labelLarge!.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
          Gap.s,
          Row(
            children: [
              _Sleeve(plates: plates, heaviest: heaviest),
              Gap.m,
              Expanded(
                child: plates.isEmpty
                    ? Text(
                        'the bare bar',
                        style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
                      )
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: perSide,
                              style: AppTheme.numeric(
                                17,
                                weight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '  per side',
                              style: t.bodySmall!.copyWith(
                                color: AppTheme.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          if (s.warning != null) ...[
            Gap.s,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppTheme.warn,
                ),
                Gap.s,
                Expanded(
                  child: Text(
                    s.warning!,
                    style: t.bodySmall!.copyWith(color: AppTheme.warn),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One sleeve of the bar, seen from the side: plates heaviest-in, then the
/// collar. Height follows weight.
class _Sleeve extends StatelessWidget {
  const _Sleeve({required this.plates, required this.heaviest});

  final List<double> plates;
  final double heaviest;

  static const _height = 46.0;

  @override
  Widget build(BuildContext context) {
    double h(double kg) {
      final frac = heaviest <= 0 ? 1.0 : math.sqrt(kg / heaviest);
      return _height * (0.34 + 0.66 * frac.clamp(0.0, 1.0));
    }

    double w(double kg) => kg >= 10 ? 9 : (kg >= 2.5 ? 7 : 5);

    return SizedBox(
      height: _height,
      width: 118,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // The sleeve itself.
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.textFaint,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Row(
            children: [
              // The inner collar the plates sit against.
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              for (final kg in plates) ...[
                Container(
                  width: w(kg),
                  height: h(kg),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF4A4A55), Color(0xFF2C2C34)],
                    ),
                    border: Border.all(color: AppTheme.outline, width: 0.8),
                  ),
                ),
                const SizedBox(width: 1.5),
              ],
              if (plates.isNotEmpty)
                Container(
                  width: 5,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.textDim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtrasCard extends StatelessWidget {
  const _ExtrasCard({required this.inventory});

  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = <(String, String)>[
      if (inventory.fixedDumbbells.isNotEmpty)
        (
          'Fixed dumbbells',
          inventory.fixedDumbbells
              .map(
                (d) =>
                    '${_fmt(d.weightKg)} kg'
                    '${d.count == 2 ? ' pair' : ' × ${d.count}'}',
              )
              .join(' · '),
        ),
      if (inventory.kettlebells.isNotEmpty)
        (
          'Kettlebell${inventory.kettlebells.length == 1 ? '' : 's'}',
          inventory.kettlebells.map((k) => '${_fmt(k)} kg').join(' · '),
        ),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.outlineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(rows[i].$1, style: t.titleMedium),
                  Gap.m,
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.step,
    required this.min,
    required this.suffix,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final double value;
  final double step;
  final double min;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final down = double.parse(
      (value - step).clamp(min, 999.0).toStringAsFixed(2),
    );
    final up = double.parse((value + step).toStringAsFixed(2));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Tap(
          key: ValueKey('$keyPrefix-minus'),
          icon: Icons.remove,
          label: 'Less: $label',
          onTap: value - step < min - 1e-9 ? null : () => onChanged(down),
        ),
        SizedBox(
          width: 70,
          child: Text(
            '${_fmt(value)}${suffix.isEmpty ? '' : ' $suffix'}',
            textAlign: TextAlign.center,
            style: AppTheme.numeric(20),
          ),
        ),
        _Tap(
          key: ValueKey('$keyPrefix-plus'),
          icon: Icons.add,
          label: 'More: $label',
          onTap: () => onChanged(up),
        ),
      ],
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Icon(
            icon,
            size: 22,
            color: onTap == null ? AppTheme.textFaint : AppTheme.text,
          ),
        ),
      ),
    );
  }
}
