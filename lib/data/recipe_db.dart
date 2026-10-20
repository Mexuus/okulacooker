import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/ingredient.dart';
import '../models/recipe.dart';

/// The recipe database (494 dinners, 202 ingredients) imported from the
/// original app by `tool/import_recipe_db.py`. Loaded once at startup.
class RecipeDb {
  static const assetPath = 'assets/data/recipe_db.json';

  final int version;
  final Map<String, Ingredient> ingredients;
  final List<Recipe> recipes;
  final Map<String, Recipe> _byId;

  RecipeDb({required this.version, required this.ingredients, required this.recipes})
      : _byId = {for (final r in recipes) r.id: r};

  factory RecipeDb.fromJson(Map<String, dynamic> j) {
    final ings = {
      for (final raw in (j['ingredients'] as List).cast<Map<String, dynamic>>())
        raw['canonical_id'] as String: Ingredient.fromJson(raw),
    };
    final recipes = (j['recipes'] as List)
        .cast<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList();
    return RecipeDb(version: (j['version'] as num).toInt(), ingredients: ings, recipes: recipes);
  }

  factory RecipeDb.fromJsonString(String s) =>
      RecipeDb.fromJson(jsonDecode(s) as Map<String, dynamic>);

  static RecipeDb? _instance;

  static RecipeDb get instance =>
      _instance ?? (throw StateError('RecipeDb not loaded; call RecipeDb.load() first'));

  static set instance(RecipeDb db) => _instance = db;

  static bool get isLoaded => _instance != null;

  static Future<RecipeDb> load() async =>
      _instance = RecipeDb.fromJsonString(await rootBundle.loadString(assetPath));

  Recipe? byId(String id) => _byId[id];
}

/// All ingredients keyed by id.
Map<String, Ingredient> get kIngredients => RecipeDb.instance.ingredients;

/// All recipes.
List<Recipe> get kRecipes => RecipeDb.instance.recipes;

/// The recipe with [id]; falls back to the first recipe if unknown.
Recipe recipeById(String id) => RecipeDb.instance.byId(id) ?? kRecipes.first;

/// Whether [id] is a recipe in the database (old saved plans may not be).
bool isKnownRecipe(String id) => RecipeDb.instance.byId(id) != null;

Ingredient ingredientById(String id) =>
    kIngredients[id] ?? (throw ArgumentError('Unknown ingredient id: $id'));
