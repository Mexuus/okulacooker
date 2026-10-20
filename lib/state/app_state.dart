import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/recipe_db.dart';
import '../data/zip_states.dart';
import '../models/grocery.dart';
import '../models/pantry.dart';
import '../models/plan.dart';
import '../models/recipe.dart';
import '../models/settings.dart';
import '../models/store.dart';
import '../models/store_location.dart';
import '../services/grocery_builder.dart';
import '../services/location_service.dart';
import '../services/persistence.dart';
import '../services/plan_generator.dart';
import '../services/pricing.dart';
import '../services/store_locator.dart';

/// Pantry basics most kitchens already have, pre-ticked when the user says so.
const kBasicStaples = {
  'salt_kosher', 'pepper_black', 'oil_neutral', 'olive_oil_evoo', 'sugar_white',
  'sugar_brown', 'flour_ap', 'baking_soda', 'baking_powder', 'garlic_powder',
  'onion_powder', 'chili_flake', 'cumin_ground', 'paprika_sweet', 'oregano_dried',
  'italian_seasoning', 'soy_sauce', 'ketchup', 'mayo', 'mustard_dijon', 'honey',
  'vinegar_apple_cider', 'cornstarch', 'hot_sauce', 'chili_powder', 'cinnamon_ground',
};

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

  /// Every recipe ever put in a plan -> date (yyyy-MM-dd) it was last planned.
  /// The planner never reuses these until the whole library has been used.
  Map<String, String> _recipeLog;
  Set<String> _favorites;

  /// Device location + offline ZIP lookup.
  final LocationService location;

  /// Nearby-store lookup (bundled directory, OpenStreetMap fallback).
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
        _freezer = _store.loadFreezer(),
        _recipeLog = _store.loadRecipeLog(),
        _favorites = _store.loadFavorites() {
    _dropUnknownRecipes();
  }

  /// Plans saved by older versions may reference recipes that no longer exist.
  void _dropUnknownRecipes() {
    bool known(WeekPlan p) =>
        [...p.meals, ...p.weekTwoMeals].every((m) => isKnownRecipe(m.recipeId));
    if (_plan != null && !known(_plan!)) {
      _plan = null;
      _store.saveCurrentPlan(null);
    }
    final kept = _history.where(known).toList();
    if (kept.length != _history.length) {
      _history = kept;
      _store.saveHistory(_history);
    }
    final freezer = _freezer.where((f) => isKnownRecipe(f.recipeId)).toList();
    if (freezer.length != _freezer.length) {
      _freezer = freezer;
      _store.saveFreezer(_freezer);
    }
    _recipeLog.removeWhere((id, _) => !isKnownRecipe(id));
    _favorites.removeWhere((id) => !isKnownRecipe(id));
    _migratePantry();
  }

  /// Ingredient ids from versions before the recipe database.
  static const _legacyStaples = {
    'salt': 'salt_kosher', 'pepper': 'pepper_black', 'olive_oil': 'olive_oil_evoo',
    'veg_oil': 'oil_neutral', 'soy_sauce': 'soy_sauce', 'honey': 'honey', 'ketchup': 'ketchup',
    'mayo': 'mayo', 'flour': 'flour_ap', 'sugar': 'sugar_white', 'cumin': 'cumin_ground',
    'chili_powder': 'chili_powder', 'paprika': 'paprika_sweet', 'garlic_powder': 'garlic_powder',
    'italian_seasoning': 'italian_seasoning', 'curry_powder': 'curry_powder',
    'cornstarch': 'cornstarch', 'sesame_oil': 'sesame_oil', 'butter': 'butter_unsalted',
  };

  void _migratePantry() {
    final ids = _pantry.ownedStapleIds;
    final unknown = ids.where((id) => !kIngredients.containsKey(id)).toList();
    if (unknown.isEmpty) return;
    for (final id in unknown) {
      ids.remove(id);
      final mapped = _legacyStaples[id];
      if (mapped != null && kIngredients.containsKey(mapped)) ids.add(mapped);
    }
    _store.savePantry(_pantry);
  }

  /// Ticks the common pantry basics ([kBasicStaples]) as owned.
  Future<void> stockBasics() async {
    _pantry.ownedStapleIds.addAll(kBasicStaples.where(kIngredients.containsKey));
    await _store.savePantry(_pantry);
    notifyListeners();
  }

  // ---- Getters ----
  UserSettings get settings => _settings;
  WeekPlan? get plan => _plan;
  List<WeekPlan> get history => List.unmodifiable(_history);
  PantryState get pantry => _pantry;
  List<FreezerItem> get freezer => List.unmodifiable(_freezer);
  bool get onboarded => _settings.onboarded;
  Set<String> get favorites => Set.unmodifiable(_favorites);
  bool isFavorite(String recipeId) => _favorites.contains(recipeId);

  /// Date (yyyy-MM-dd) the recipe was last planned, or null if never.
  String? lastPlanned(String recipeId) => _recipeLog[recipeId];

  /// Recipes compatible with diet, won't-eat, and equipment settings.
  List<Recipe> get allowedRecipeList => allowedRecipes(_settings);

  /// Allowed recipes never planned yet.
  int get newRecipeCount =>
      allowedRecipeList.where((r) => !_recipeLog.containsKey(r.id)).length;

  PricingEngine get pricing => PricingEngine.forSettings(_settings);

  GroceryList? get groceryList => groceryListFor(pricing);

  /// This week's grocery list priced by [engine] (e.g. at another store).
  GroceryList? groceryListFor(PricingEngine engine) {
    final p = _plan;
    if (p == null) return null;
    return GroceryBuilder(pricing: engine, ownedStaples: _pantry.ownedStapleIds).build(p);
  }

  /// Pricing for a specific nearby store location.
  PricingEngine pricingAt(NearbyStore n) => PricingEngine(
        store: n.store,
        location: PriceLocation(
          lat: n.lat,
          lng: n.lng,
          state: n.state ?? stateForZip(_settings.zip),
          label: n.address ?? n.displayName,
        ),
      );

  /// This week's total at [engine]'s store (both weeks when shopping two weeks).
  double? planTotalAt(PricingEngine engine) {
    final list = groceryListFor(engine);
    return list == null ? null : list.total + list.laterTotal;
  }

  /// Local price level vs. the national average for a typical basket (every
  /// ingredient the recipe library uses), e.g. 1.06 = 6% above average.
  double priceLevelAt(PricingEngine engine) {
    final national = PricingEngine(
      store: const Store(id: '_avg', name: 'Average', priceMultiplier: 1.0),
      location: const PriceLocation(label: 'National average'),
    );
    var local = 0.0, avg = 0.0;
    for (final ing in kIngredients.values) {
      local += engine.quote(ing).localPackPrice;
      avg += national.quote(ing).localPackPrice;
    }
    return avg == 0 ? 1.0 : local / avg;
  }

  /// Nearby stores (closest location per chain) with this week's total at
  /// each, cheapest first.
  Future<List<(NearbyStore, double)>> compareNearbyStores({double radiusMiles = 10}) async {
    final loc = PriceLocation.forSettings(_settings);
    double? lat = loc.lat, lng = loc.lng;
    if (lat == null || lng == null) {
      final place = await currentPlace();
      if (place == null) return const [];
      lat = place.lat;
      lng = place.lng;
    }
    final stores = StoreLocator.closestPerChain(
        await storeLocator.nearby(lat, lng, radiusMiles: radiusMiles));
    final out = <(NearbyStore, double)>[
      for (final n in stores)
        if (planTotalAt(pricingAt(n)) case final total?) (n, total),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return out;
  }

  /// Switches the store, optionally to an exact location (prices then follow
  /// that location's region and metro area).
  Future<void> selectStore(String storeId, {StoreLocationRef? location}) =>
      updateSettings(_settings.copyWith(
        storeId: storeId,
        storeLocation: location,
        clearStoreLocation: location == null,
      ));

  PlanGenerator _generator() => PlanGenerator(
        pricing: pricing,
        ownedStaples: _pantry.ownedStapleIds,
        pool: allowedRecipes(_settings),
        history: _recipeLog,
      );

  // ---- Location ----
  /// Detects the user's ZIP from device GPS (offline reverse geocoding).
  Future<PlaceInfo> detectLocation() => location.detect();

  /// Coordinates/state/region for the saved ZIP, or null if unknown.
  Future<PlaceInfo?> currentPlace() => location.resolveZip(_settings.zip);

  /// Known-chain stores near [place], nearest first.
  Future<List<NearbyStore>> nearbyStores(PlaceInfo place, {double radiusMiles = 10}) =>
      storeLocator.nearby(place.lat, place.lng, radiusMiles: radiusMiles);

  // ---- Onboarding / settings ----
  Future<void> completeOnboarding(UserSettings s, {bool stockBasics = false}) async {
    _settings = s.copyWith(onboarded: true);
    await _store.saveSettings(_settings);
    if (stockBasics) {
      _pantry.ownedStapleIds.addAll(kBasicStaples.where(kIngredients.containsKey));
      await _store.savePantry(_pantry);
    }
    await generatePlan();
    await _ensureZipCoordinates();
  }

  Future<void> updateSettings(UserSettings s) async {
    final planAffecting = s.householdSize != _settings.householdSize ||
        s.cookNights.length != _settings.cookNights.length ||
        s.twoWeekMode != _settings.twoWeekMode ||
        !setEquals(s.diets, _settings.diets) ||
        !setEquals(s.excludedIngredients, _settings.excludedIngredients) ||
        !setEquals(s.equipment, _settings.equipment);
    _settings = s;
    await _store.saveSettings(_settings);
    if (planAffecting && _plan != null) {
      await generatePlan(archive: false);
    } else {
      notifyListeners();
    }
    await _ensureZipCoordinates();
  }

  /// Fills in the ZIP centroid (offline) so metro-area pricing works even
  /// before a specific store location is picked.
  Future<void> _ensureZipCoordinates() async {
    final zip = _settings.zip;
    if (zip.isEmpty || _settings.zipLat != null) return;
    final place = await location.resolveZip(zip);
    if (place == null || _settings.zip != zip) return;
    _settings = _settings.copyWith(zipLat: place.lat, zipLng: place.lng);
    await _store.saveSettings(_settings);
    notifyListeners();
  }

  /// Call once after construction: backfills ZIP coordinates and replaces a
  /// plan that older versions saved with recipes no longer in the database.
  Future<void> init() async {
    if (_settings.onboarded && _plan == null) await generatePlan(archive: false);
    await _ensureZipCoordinates();
  }

  Future<void> setTheme(AppTheme theme) async {
    _settings.theme = theme;
    await _store.saveSettings(_settings);
    notifyListeners();
  }

  // ---- Recipe log ----
  Future<void> _logRecipes(Iterable<String> ids) async {
    final today = mondayOfWeek(DateTime.now());
    for (final id in ids) {
      _recipeLog[id] = today;
    }
    await _store.saveRecipeLog(_recipeLog);
  }

  /// Forget which recipes have been planned (everything becomes "new" again).
  Future<void> resetRecipeHistory() async {
    _recipeLog.clear();
    await _store.saveRecipeLog(_recipeLog);
    notifyListeners();
  }

  Future<void> toggleFavorite(String recipeId) async {
    if (!_favorites.remove(recipeId)) _favorites.add(recipeId);
    await _store.saveFavorites(_favorites);
    notifyListeners();
  }

  // ---- Plan actions ----
  Future<void> generatePlan({bool archive = true}) async {
    if (archive && _plan != null) {
      _history.insert(0, _plan!);
      if (_history.length > historyLimit) _history = _history.sublist(0, historyLimit);
      await _store.saveHistory(_history);
    }
    _plan = _generator().generate(_settings);
    await _logRecipes([..._plan!.meals, ..._plan!.weekTwoMeals].map((m) => m.recipeId));
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  List<PlannedMeal> _mealsFor(bool weekTwo) =>
      weekTwo ? (_plan?.weekTwoMeals ?? const []) : (_plan?.meals ?? const []);

  /// Replaces a meal with a recipe the user has never been given.
  Future<void> swapMeal(int slot, {bool weekTwo = false}) async {
    final p = _plan;
    if (p == null) return;
    final meals = _mealsFor(weekTwo);
    final meal = meals.firstWhere((m) => m.slot == slot);
    final used = {...p.meals, ...p.weekTwoMeals}.map((m) => m.recipeId).toSet();
    final others = meals.where((m) => m != meal).map((m) => recipeById(m.recipeId)).toList();
    meal.recipeId = _generator().swapRecipe(meal.recipeId, used, others: others);
    meal.skipped = false;
    await _logRecipes([meal.recipeId]);
    await _store.saveCurrentPlan(_plan);
    notifyListeners();
  }

  /// Puts a recipe the user picked into a night. Picked meals may repeat
  /// recipes from earlier weeks — only automatic suggestions never repeat.
  Future<void> chooseMeal(int slot, String recipeId, {bool weekTwo = false}) async {
    final meals = _mealsFor(weekTwo);
    final meal = meals.where((m) => m.slot == slot).firstOrNull;
    if (meal == null) return;
    meal.recipeId = recipeId;
    meal.skipped = false;
    meal.fromFreezer = false;
    await _logRecipes([recipeId]);
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
    if (!_pantry.ownedStapleIds.remove(ingredientId)) _pantry.ownedStapleIds.add(ingredientId);
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
    _recipeLog = {};
    _favorites = {};
    await _store.saveSettings(_settings);
    await _store.saveCurrentPlan(null);
    await _store.saveHistory(_history);
    await _store.savePantry(_pantry);
    await _store.saveFreezer(_freezer);
    await _store.saveRecipeLog(_recipeLog);
    await _store.saveFavorites(_favorites);
    notifyListeners();
  }
}
