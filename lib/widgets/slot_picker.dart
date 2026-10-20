import 'package:flutter/material.dart';

import '../data/recipe_db.dart';
import '../state/app_state.dart';

const _weekday = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

/// Label for a plan slot, e.g. "Tue" (falls back to "Night 2").
String slotLabel(AppState state, int slot) {
  final nights = [...state.settings.cookNights]..sort();
  return slot < nights.length ? _weekday[nights[slot]]! : 'Night ${slot + 1}';
}

/// Lets the user pick which night of the current plan a recipe should go on.
/// Returns (slot, weekTwo) or null if cancelled.
Future<(int, bool)?> showSlotPicker(BuildContext context, AppState state, {String? title}) {
  final plan = state.plan;
  if (plan == null) return Future.value(null);
  final theme = Theme.of(context);

  Widget tile(BuildContext ctx, int slot, String recipeId, bool weekTwo) {
    final r = recipeById(recipeId);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(slotLabel(state, slot),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer)),
      ),
      title: Text(r.title),
      subtitle: const Text('Replace this dinner'),
      onTap: () => Navigator.pop(ctx, (slot, weekTwo)),
    );
  }

  return showModalBottomSheet<(int, bool)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title ?? 'Which night?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final m in plan.meals) tile(ctx, m.slot, m.recipeId, false),
            if (plan.isTwoWeek) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Next week', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (final m in plan.weekTwoMeals) tile(ctx, m.slot, m.recipeId, true),
            ],
          ],
        ),
      ),
    ),
  );
}
