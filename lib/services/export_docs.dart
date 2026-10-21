/// Builds the [ExportDoc]s the export sheet offers for the grocery list, the
/// week's dinners and a single recipe.
library;

import '../data/recipe_db.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../widgets/slot_picker.dart';
import 'export_formats.dart';

ExportContext exportContextFor(AppState state) {
  final pricing = state.pricing;
  final loc = state.settings.storeLocation;
  final storeName = loc != null && loc.storeId == pricing.store.id
      ? loc.label
      : pricing.store.name;
  return ExportContext(
    storeName: storeName,
    areaName: pricing.areaName,
    weekStart: state.plan?.weekStart,
  );
}

/// The grocery list: text, CSV, printable HTML and a webhook payload.
/// Returns null when there is no plan to shop for yet.
ExportDoc? groceryExportDoc(AppState state) {
  final list = state.groceryList;
  if (list == null) return null;
  final ctx = exportContextFor(state);
  final plan = state.plan;

  return ExportDoc(
    title: 'Grocery list',
    fileStem: exportFileStem('grocery', ctx.generatedAt),
    text: (o) => groceryListText(list, o, ctx),
    html: (o) => groceryListHtml(list, o, ctx),
    csv: (o) => groceryListCsv(list, o, ctx),
    json: (o) => groceryListJson(
      list,
      o,
      ctx,
      meals: plan?.meals ?? const [],
      mealLabel: (m) => slotLabel(state, m.slot),
      lookupRecipe: recipeById,
    ),
  );
}

/// The week's dinners.
ExportDoc? planExportDoc(AppState state) {
  final plan = state.plan;
  if (plan == null) return null;
  final ctx = exportContextFor(state);

  return ExportDoc(
    title: 'Meal plan',
    fileStem: exportFileStem('dinners', ctx.generatedAt),
    showOptions: false,
    text: (_) => weekPlanText(
      plan.meals,
      recipeById,
      (m) => slotLabel(state, m.slot),
      ctx,
      weekTwo: plan.weekTwoMeals,
    ),
    html: (_) => weekPlanHtml(
      plan.meals,
      recipeById,
      (m) => slotLabel(state, m.slot),
      ctx,
      weekTwo: plan.weekTwoMeals,
    ),
  );
}

/// One recipe, scaled to the servings the user is cooking.
ExportDoc recipeExportDoc(Recipe recipe, int servings) => ExportDoc(
      title: 'Recipe',
      fileStem: exportFileStem(recipe.id, DateTime.now()),
      showOptions: false,
      text: (_) => recipeText(recipe, servings),
      html: (_) => recipeHtml(recipe, servings),
    );
