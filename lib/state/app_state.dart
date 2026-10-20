import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/settings.dart';
import '../models/plan.dart';
import '../models/pantry.dart';
import '../models/grocery.dart';
import '../services/persistence.dart';
import '../services/pricing.dart';
import '../services/grocery_builder.dart';
import '../services/plan_generator.dart';
import '../services/location_service.dart';
import '../services/store_locator.dart';
import '../models/recipe.dart';

/// App-wide state and the single source of truth for the UI. All mutations
/// persist locally and notify listeners.
class AppState extends ChangeNotifier {
  final Persistence _store;
  static const _uuid = Uuid();
  static const int historyLimit = 3;

  UserSettings _settings;
  WeekPlan? _plan;
  List<WeekPlan> _history;
  PantryState _pantry;
  List<FreezerItem> _freezer;

  /// Device location + offline ZIP lookup.
  final LocationService location;

  /// Nearby-store lookup (OpenStreetMap, free, no key).
  final StoreLocator storeLocator;

  AppState(
    this._store, {
    LocationService? location,
    StoreLocator? storeLocator,
  })  : location = location ?? LocationService(),
        storeLocator = storeLocator ?? StoreLocator(),
        _settings = _store.loadSettings(),
        _plan = _store.loadCurrentPlan(),
        _history = _store.loadHistory(),
        _pantry = _store.loadPantry(),
        _freezer = _store.loadFreezer();

  // ---- Getters ----
  UserSettings get settings => _settings;
  WeekPlan? get plan => _plan;
  List<WeekPlan> get history => List.unmodifiable(_history);
  PantryState get pantry => _pantry;
  List<FreezerItem> get freezer => List.unmodifiable(_freezer);
  bool get onboarded => _settings.onboarded;

  PricingEngine get pricing =>
      PricingEngine.from(storeId: _settings.storeId, zip: _settings.zip);

  GroceryList? get groceryList {
    final p = _plan;
    if (p == null) return null;
    return GroceryBuilder(
      pricing: pricing,
      ownedStaples: _pantry.ownedStapleIds,
    ).build(p);
  }

  PlanGenerator _generator() => PlanGenerator(
        pricing: pricing,
        ownedStaples: _pantry.ownedStapleIds,
        pool: allowedRecipes(_settings),
      );

  /// Recipes compatible with the current diet / won't-eat settings.
  List<Recipe> get allowedRecipeList => allowedRecipes(_settings);

  // ---- Location ----
  /// Detects the user's ZIP from device GPS (offline reverse geocoding).
  Future<PlaceInfo> detectLocation() => location.detect();

  /// Coordinates/state/region for the saved ZIP, or null if unknown.
  Future<PlaceInfo?> currentPlace() => location.resolveZip(_settings.zip);

  /// Known-chain stores near [place], nearest first.
  Future<List<NearbyStore>> nearbyStores(PlaceInfo place,
          {double radiusMiles = 10}) =>
      storeLocator.nearby(place.lat, place.lng, radiusMiles: radiusMiles);

  // ---- Onboarding / settings ----
  Future<void> completeOnboarding(UserSettings s) async {
    _settings = s.copyWith(onboarded: true);
    await _store.saveSettings(_settings);
    generatePlan();
  }

  Future<void> updateSettings(UserSettings s) async {
    final planAffecting = s.householdSize != _settings.householdSize ||
        s.cookNights.length != _settings.cookNights.length ||
        s.twoWeekMode != _settings.twoWeekMode ||
        !setEquals(s.diets, _settings.diets) ||
        !setEquals(s.excludedIngredients, _settings.excludedIngredients);
    _settings = s;
    await _store.saveSettings(_settings);
    if (planAffecting && _plan != null) {
      generatePlan(archive: false);
    } else {
      notifyListeners();
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _settings.theme = theme;
    await _store.saveSettings(_settings);
    notifyListeners();
  }

  // ---- Plan actions ----
  Future<void> generatePlan({bool archive = true}) async {
    if (archive && _plan != null) {
      _history.insert(0, _plan!);
      if (_history.length > historyLimit) {
        _history = _history.sublist(0, historyLimit);
      }
      await _store.saveHistory(_history);
    }
    _plan = _generator().generate(_settings);
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  Future<void> swapMeal(int slot) async {
    final p = _plan;
    if (p == null) return;
    final meal = p.meals.firstWhere((m) => m.slot == slot);
    final used = p.meals.map((m) => m.recipeId).toSet()
      ..addAll(p.weekTwoMeals.map((m) => m.recipeId));
    meal.recipeId = _generator().swapRecipe(meal.recipeId, used);
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  Future<void> toggleSkip(int slot) async {
    final meal = _plan?.meals.firstWhere((m) => m.slot == slot);
    if (meal == null) return;
    meal.skipped = !meal.skipped;
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  Future<void> setServings(int slot, int servings) async {
    final meal = _plan?.meals.firstWhere((m) => m.slot == slot);
    if (meal == null) return;
    meal.servings = servings.clamp(1, 20);
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  Future<void> toggleFromFreezer(int slot) async {
    final meal = _plan?.meals.firstWhere((m) => m.slot == slot);
    if (meal == null) return;
    meal.fromFreezer = !meal.fromFreezer;
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  // ---- Pantry ----
  Future<void> togglePantryStaple(String ingredientId) async {
    if (_pantry.ownedStapleIds.contains(ingredientId)) {
      _pantry.ownedStapleIds.remove(ingredientId);
    } else {
      _pantry.ownedStapleIds.add(ingredientId);
    }
    await _store.savePantry(_pantry);
    notifyListeners();
  }

  Future<void> clearPantry() async {
    _pantry.ownedStapleIds.clear();
    await _store.savePantry(_pantry);
    notifyListeners();
  }

  // ---- Freezer / leftovers ----
  Future<void> freezeExtra(String recipeId, int servings) async {
    _freezer.insert(
      0,
      FreezerItem(
        id: _uuid.v4(),
        recipeId: recipeId,
        servings: servings,
        frozenOn: mondayOfWeek(DateTime.now()),
      ),
    );
    await _store.saveFreezer(_freezer);
    notifyListeners();
  }

  Future<void> removeFreezerItem(String id) async {
    _freezer.removeWhere((f) => f.id == id);
    await _store.saveFreezer(_freezer);
    notifyListeners();
  }

  /// Fully resets the app to a fresh state (useful for testing / re-onboarding).
  Future<void> resetAll() async {
    _settings = UserSettings();
    _plan = null;
    _history = [];
    _pantry = PantryState();
    _freezer = [];
    await _store.saveSettings(_settings);
    await _store.saveCurrentPlan(null);
    await _store.saveHistory(_history);
    await _store.savePantry(_pantry);
    await _store.saveFreezer(_freezer);
    notifyListeners();
  }
}
