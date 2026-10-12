import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/fuel_providers.dart';
import '../../app/providers.dart';
import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/fuel/fuel_plan.dart';
import '../common/widgets.dart';
import 'widgets/swap_sheet.dart';

/// The Plan: a week of eating laid out before it happens — what each day
/// is, what to cook ahead and when, and what to buy — for this week or the
/// next.
///
/// Built for a student: every day shows what it costs, the default week
/// buys one main protein a day, and the shopping list is in the packets the
/// shop sells, ticked off at the shelf.
class FuelWeekView extends ConsumerStatefulWidget {
  const FuelWeekView({super.key});

  @override
  ConsumerState<FuelWeekView> createState() => _FuelWeekViewState();
}

class _FuelWeekViewState extends ConsumerState<FuelWeekView> {
  /// From Friday the week worth planning is the next one: the shop is at the
  /// weekend and Sunday's cooking is for Monday.
  late bool _next = ref.read(todayProvider).weekday >= DateTime.friday;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final thisMonday = mondayOf(today);
    final monday = _next
        ? DateTime(thisMonday.year, thisMonday.month, thisMonday.day + 7)
        : thisMonday;
    final week = ref.watch(fuelWeekProvider(monday));

    return ListView(
      padding: Gap.pagePadding,
      children: [
        Row(
          children: [
            Expanded(
              child: _WeekTab(
                title: 'This week',
                monday: thisMonday,
                selected: !_next,
                onTap: () => setState(() => _next = false),
              ),
            ),
            Gap.s,
            Expanded(
              child: _WeekTab(
                title: 'Next week',
                monday: DateTime(
                  thisMonday.year,
                  thisMonday.month,
                  thisMonday.day + 7,
                ),
                selected: _next,
                onTap: () => setState(() => _next = true),
              ),
            ),
          ],
        ),
        Gap.m,
        ...week.when(
          loading: () => const [
            Skeleton(height: 120),
            Gap.m,
            Skeleton(height: 300),
          ],
          error: (e, _) => [
            AsyncScaffoldBody(
              loading: false,
              error: e,
              child: const SizedBox(),
            ),
          ],
          data: (days) => _sections(context, days, monday, today),
        ),
      ],
    );
  }

  List<Widget> _sections(
    BuildContext context,
    List<FuelDay> days,
    DateTime monday,
    DateTime today,
  ) {
    if (days.isEmpty) return const [];
    final plan = days.first.plan;
    final nights = plan.prepNights(monday: monday, week: days);
    final lines = plan.groceries(days);
    final t = Theme.of(context).textTheme;

    return [
      _CostCard(days: days, budget: plan.budget),
      const SectionHeader('Cook ahead'),
      if (nights.isEmpty)
        Text(
          'Nothing to cook ahead: every meal this week is made on the day.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        )
      else
        for (final n in nights)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PrepCard(
              night: n,
              today: today,
              keepsDays: plan.prep?.keepsDays,
            ),
          ),
      const SectionHeader('The week'),
      for (var i = 0; i < days.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DayCard(
            day: days[i],
            date: DateTime(monday.year, monday.month, monday.day + i),
            today: today,
          ),
        ),
      _ShoppingList(monday: monday, lines: lines, days: days),
      Gap.l,
      _Guide(plan: plan),
    ];
  }
}

String _eur(double v) => '€${v.toStringAsFixed(2)}';

class _WeekTab extends StatelessWidget {
  const _WeekTab({
    required this.title,
    required this.monday,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final DateTime monday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final range =
        '${DateFormat('d MMM').format(monday)} – '
        '${DateFormat('d MMM').format(sunday)}';
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: AnimatedContainer(
          duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.crimson.withValues(alpha: 0.18)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: selected ? AppTheme.crimson : AppTheme.outline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? AppTheme.text : AppTheme.textFaint,
              ),
              Gap.s,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    Text(
                      range,
                      style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the week's food costs against what a student can spend.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.days, required this.budget});

  final List<FuelDay> days;
  final FuelBudget? budget;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = days.fold<double>(0, (a, d) => a + d.costEur);
    final perDay = total / days.length;
    final b = budget;
    final under = b == null || total <= b.eurPerWeek;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Food this week',
                  value: total,
                  decimals: 2,
                  glyph: '€',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'A day',
                  value: perDay,
                  decimals: 2,
                  glyph: '€',
                  color: AppTheme.textDim,
                ),
              ),
            ],
          ),
          if (b != null) ...[
            Gap.m,
            Row(
              children: [
                Icon(
                  under ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 18,
                  color: under ? AppTheme.good : AppTheme.warn,
                ),
                Gap.s,
                Expanded(
                  child: Text(
                    under
                        ? 'Under the ${_eur(b.eurPerWeek)} a week this plan '
                              'is built to'
                        : 'Over the ${_eur(b.eurPerWeek)} a week this plan '
                              'is built to — a dear swap or two',
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
            if (b.note != null) ...[
              Gap.xs,
              Text(
                b.note!,
                style: t.bodySmall?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PrepCard extends StatelessWidget {
  const _PrepCard({
    required this.night,
    required this.today,
    required this.keepsDays,
  });

  final PrepNight night;
  final DateTime today;
  final int? keepsDays;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tonight = night.cookDate == today;
    final past = night.cookDate.isBefore(today);
    final forDays = {
      for (final m in night.meals) DateFormat('EEE').format(m.date),
    }.join(' and ');

    return Opacity(
      opacity: past ? 0.6 : 1,
      child: AppCard(
        accent: tonight ? AppTheme.crimson : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  past ? Icons.check_circle_outline : Icons.soup_kitchen,
                  color: past ? AppTheme.textDim : AppTheme.crimson,
                ),
                Gap.s,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(night.session.label, style: t.titleMedium),
                      Text(
                        '${DateFormat('EEE d MMM').format(night.cookDate)}'
                        '${tonight
                            ? ' · tonight'
                            : past
                            ? ' · done'
                            : ''}',
                        style: t.bodySmall?.copyWith(
                          color: tonight ? AppTheme.text : AppTheme.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap.s,
            Text(
              'Cook for $forDays: ${night.meals.length} '
              '${night.meals.length == 1 ? 'meal' : 'meals'}.',
              style: t.bodyMedium,
            ),
            Gap.s,
            for (final c in night.cook)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(c.food.name, style: t.bodyMedium)),
                    Gap.s,
                    Text(
                      '${c.grams.round()} g',
                      style: AppTheme.numeric(17, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            Gap.s,
            for (final m in night.meals)
              Text(
                '${DateFormat('EEE').format(m.date)} ${m.slot.name.toLowerCase()}'
                ' — ${m.meal.name}',
                style: t.bodySmall?.copyWith(color: AppTheme.textDim),
              ),
            if (keepsDays != null) ...[
              Gap.s,
              Row(
                children: [
                  const Icon(
                    Icons.kitchen_outlined,
                    size: 16,
                    color: AppTheme.textDim,
                  ),
                  Gap.xs,
                  Expanded(
                    child: Text(
                      'Into the fridge once it has cooled, within two hours. '
                      'Keeps $keepsDays days; reheat until steaming.',
                      style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One day of the week: what it is built around, what it costs, and — open
/// — every meal, each one swappable.
class _DayCard extends ConsumerStatefulWidget {
  const _DayCard({required this.day, required this.date, required this.today});

  final FuelDay day;
  final DateTime date;
  final DateTime today;

  @override
  ConsumerState<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<_DayCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final day = widget.day;
    final isToday = widget.date == widget.today;
    final past = widget.date.isBefore(widget.today);
    final mains = day.meatOrFish;
    PlannedMeal? slot(String id) =>
        day.slots.where((s) => s.slot.id == id).firstOrNull;
    final lunch = slot('lunch');
    final dinner = slot('dinner');

    return AppCard(
      accent: isToday ? AppTheme.crimson : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      onTap: () => setState(() => _open = !_open),
      semanticLabel:
          '${DateFormat('EEEE d MMMM').format(widget.date)}, '
          '${_open ? 'open' : 'closed'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE d MMM').format(widget.date),
                      style: t.titleMedium?.copyWith(
                        color: past ? AppTheme.textDim : AppTheme.text,
                      ),
                    ),
                    if (isToday)
                      Text(
                        'TODAY',
                        style: AppTheme.overline.copyWith(
                          color: AppTheme.crimson,
                        ),
                      ),
                    _Kind(training: day.isTrainingDay),
                  ],
                ),
              ),
              Text(
                _eur(day.costEur),
                style: AppTheme.numeric(18, weight: FontWeight.w600),
              ),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.textDim,
              ),
            ],
          ),
          Gap.s,
          if (!_open) ...[
            if (lunch != null) _Line(label: 'Lunch', meal: lunch.chosen.name),
            if (dinner != null)
              _Line(label: 'Dinner', meal: dinner.chosen.name),
          ] else
            for (final s in day.slots)
              _SlotRow(
                slot: s,
                canSwap: !past,
                onSwap: () => _swap(context, s),
              ),
          if (mains.length > 1) ...[
            Gap.s,
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 16, color: AppTheme.warn),
                Gap.xs,
                Expanded(
                  child: Text(
                    'Two mains to buy and cook today: ${mains.join(' and ')}',
                    style: t.bodySmall?.copyWith(color: AppTheme.warn),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _swap(BuildContext context, PlannedMeal slot) async {
    final picked = await showModalBottomSheet<Meal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => SwapSheet(slot: slot, plan: widget.day.plan),
    );
    if (picked == null || picked.id == slot.chosen.id) return;
    await ref
        .read(mealLogControllerProvider)
        .swap(day: widget.date, slot: slot, to: picked);
  }
}

class _Kind extends StatelessWidget {
  const _Kind({required this.training});

  final bool training;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        training ? Icons.fitness_center : Icons.bedtime_outlined,
        size: 14,
        color: AppTheme.textDim,
      ),
      const SizedBox(width: 4),
      Text(
        training ? 'Training' : 'Rest',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppTheme.textDim),
      ),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.meal});

  final String label;
  final String meal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: t.bodySmall?.copyWith(color: AppTheme.textDim),
            ),
          ),
          Expanded(child: Text(meal, style: t.bodyMedium)),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.canSwap,
    required this.onSwap,
  });

  final PlannedMeal slot;
  final bool canSwap;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = slot.chosen;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              slot.time,
              style: AppTheme.numeric(15, color: AppTheme.textDim),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: t.bodyMedium),
                Text(
                  '${slot.slot.name} · ${m.kcal} kcal · ${_eur(m.costEur)}'
                  '${m.batch ? ' · cooked ahead' : ''}',
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
          if (canSwap)
            IconButton(
              tooltip: 'Swap ${slot.slot.name.toLowerCase()}',
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz, color: AppTheme.textDim),
            ),
        ],
      ),
    );
  }
}

/// The week's shopping, in the order a German discounter is walked: fresh
/// produce at the door, then the dry goods, the fridges at the back.
///
/// Split in two, because a list that prices a kilo tub of whey every week
/// says the week costs twice what it does: what this week needs, and the
/// cupboard food that lasts — bought when it runs out, with how long a
/// packet goes.
class _ShoppingList extends ConsumerWidget {
  const _ShoppingList({
    required this.monday,
    required this.lines,
    required this.days,
  });

  final DateTime monday;
  final List<GroceryLine> lines;
  final List<FuelDay> days;

  static const _aisles = [
    ('veg', 'Vegetables'),
    ('fruit', 'Fruit and sweet'),
    ('grain', 'Bread, rice and pasta'),
    ('legume', 'Pulses and tofu'),
    ('fat', 'Nuts and oil'),
    ('meat', 'Meat, halal'),
    ('fish', 'Fish'),
    ('dairy', 'Dairy and eggs'),
    ('supplement', 'Supplements'),
  ];

  /// Cupboard food that would not last the week anyway goes on this week's
  /// list: it has to be bought now.
  static bool _cupboard(GroceryLine l) =>
      l.food.keeps && l.packLastsWeeks >= 1.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final ticked =
        ref.watch(preferencesProvider).asData?.value.shoppingTicksFor(monday) ??
        const <String>{};
    final shop = [
      for (final l in lines)
        if (!_cupboard(l)) l,
    ];
    final cupboard = [
      for (final l in lines)
        if (_cupboard(l)) l,
    ];
    final spend = shop.fold<double>(0, (a, l) => a + l.costEur);
    final done = lines.where((l) => ticked.contains(l.food.id)).length;
    final known = {for (final a in _aisles) a.$1};

    Widget line(GroceryLine l, {bool lasts = false}) => _ShopLine(
      line: l,
      ticked: ticked.contains(l.food.id),
      lasts: lasts ? _lasts(l.packLastsWeeks) : null,
      onTap: () {
        HapticFeedback.selectionClick();
        ref
            .read(preferencesProvider.notifier)
            .toggleShoppingTick(monday, l.food.id);
      },
    );

    bool inAisle(GroceryLine l, String cat) =>
        cat.isEmpty ? !known.contains(l.food.category) : l.food.category == cat;

    List<Widget> byAisle(List<GroceryLine> of, {bool lasts = false}) => [
      for (final (cat, name) in [..._aisles, ('', 'Other')])
        if (of.any((l) => inAisle(l, cat))) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(name.toUpperCase(), style: AppTheme.overline),
          ),
          for (final l in of)
            if (inAisle(l, cat)) line(l, lasts: lasts),
        ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Shopping list'),
        Row(
          children: [
            Expanded(
              child: Text(
                "${_eur(spend)} for this week's shop",
                style: t.titleSmall,
              ),
            ),
            Icon(
              done == lines.length && lines.isNotEmpty
                  ? Icons.check_circle
                  : Icons.shopping_basket_outlined,
              size: 18,
              color: AppTheme.textDim,
            ),
            Gap.xs,
            Text(
              '$done of ${lines.length}',
              style: AppTheme.numeric(16, color: AppTheme.textDim),
            ),
          ],
        ),
        Gap.xs,
        Text(
          'In whole packets. Tick things off at the shelf, or when they are '
          'already at home.',
          style: t.bodySmall?.copyWith(color: AppTheme.textDim),
        ),
        ...byAisle(shop),
        if (cupboard.isNotEmpty) ...[
          const SectionHeader('Cupboard, when it runs out'),
          Text(
            'Dry, tinned, bottled and frozen: one packet lasts for weeks. '
            'Buy it when it is nearly gone.',
            style: t.bodySmall?.copyWith(color: AppTheme.textDim),
          ),
          ...byAisle(cupboard, lasts: true),
        ],
      ],
    );
  }

  static String _lasts(double weeks) => weeks < 2
      ? 'lasts over a week'
      : weeks >= 8
      ? 'lasts two months or more'
      : 'lasts ${weeks.floor()} weeks';
}

class _ShopLine extends StatelessWidget {
  const _ShopLine({
    required this.line,
    required this.ticked,
    required this.onTap,
    this.lasts,
  });

  final GroceryLine line;
  final bool ticked;
  final VoidCallback onTap;

  /// How long a packet goes, for cupboard food.
  final String? lasts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ink = ticked ? AppTheme.textFaint : AppTheme.text;
    final dim = ticked ? AppTheme.textFaint : AppTheme.textDim;
    return Semantics(
      checked: ticked,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Icon(
                ticked ? Icons.check_box : Icons.check_box_outline_blank,
                color: AppTheme.textDim,
              ),
              Gap.s,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.food.name,
                      style: t.bodyLarge?.copyWith(
                        color: ink,
                        decoration: ticked ? TextDecoration.lineThrough : null,
                        decorationColor: AppTheme.textFaint,
                      ),
                    ),
                    if (lasts != null)
                      Text(lasts!, style: t.bodySmall?.copyWith(color: dim)),
                  ],
                ),
              ),
              Gap.s,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${line.packs} x ${line.food.packG} g',
                    style: t.bodyMedium?.copyWith(color: dim),
                  ),
                  Text(
                    _eur(line.costEur),
                    style: AppTheme.numeric(15, color: ink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.plan});

  final FuelPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.verified_outlined, color: AppTheme.textDim),
          title: Text('Buying it halal', style: t.titleMedium),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in plan.buyingGuide)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title, style: t.titleSmall),
                    Gap.xs,
                    Text(
                      g.body,
                      style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
