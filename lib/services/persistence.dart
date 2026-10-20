import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';
import '../models/plan.dart';
import '../models/pantry.dart';

/// Thin local-storage layer. Everything is stored on-device as JSON; there is
/// no account, server, or subscription.
class Persistence {
  static const _kSettings = 'settings';
  static const _kCurrentPlan = 'currentPlan';
  static const _kHistory = 'history';
  static const _kPantry = 'pantry';
  static const _kFreezer = 'freezer';
  static const _kRecipeLog = 'recipeLog';
  static const _kFavorites = 'favorites';

  final SharedPreferences prefs;
  Persistence(this.prefs);

  static Future<Persistence> create() async {
    final p = await SharedPreferences.getInstance();
    return Persistence(p);
  }

  // ---- Settings ----
  UserSettings loadSettings() {
    final raw = prefs.getString(_kSettings);
    if (raw == null) return UserSettings();
    return UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(UserSettings s) =>
      prefs.setString(_kSettings, jsonEncode(s.toJson()));

  // ---- Current plan ----
  WeekPlan? loadCurrentPlan() {
    final raw = prefs.getString(_kCurrentPlan);
    if (raw == null) return null;
    return WeekPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveCurrentPlan(WeekPlan? plan) {
    if (plan == null) return prefs.remove(_kCurrentPlan);
    return prefs.setString(_kCurrentPlan, jsonEncode(plan.toJson()));
  }

  // ---- History (most recent first, capped by caller) ----
  List<WeekPlan> loadHistory() {
    final raw = prefs.getString(_kHistory);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => WeekPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveHistory(List<WeekPlan> history) =>
      prefs.setString(_kHistory, jsonEncode(history.map((p) => p.toJson()).toList()));

  // ---- Pantry ----
  PantryState loadPantry() {
    final raw = prefs.getString(_kPantry);
    if (raw == null) return PantryState();
    return PantryState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> savePantry(PantryState p) =>
      prefs.setString(_kPantry, jsonEncode(p.toJson()));

  // ---- Freezer ----
  List<FreezerItem> loadFreezer() {
    final raw = prefs.getString(_kFreezer);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => FreezerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFreezer(List<FreezerItem> items) =>
      prefs.setString(_kFreezer, jsonEncode(items.map((f) => f.toJson()).toList()));

  // ---- Recipe log: every recipe ever planned -> date last planned ----
  Map<String, String> loadRecipeLog() {
    final raw = prefs.getString(_kRecipeLog);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveRecipeLog(Map<String, String> log) =>
      prefs.setString(_kRecipeLog, jsonEncode(log));

  // ---- Favorites ----
  Set<String> loadFavorites() =>
      (prefs.getStringList(_kFavorites) ?? const []).toSet();

  Future<void> saveFavorites(Set<String> ids) =>
      prefs.setStringList(_kFavorites, ids.toList());
}
