import '../services/diet.dart';
import 'store_location.dart';

/// App visual theme. Fall is the seasonal theme requested; others are provided
/// for variety. No subscription is required to use any of them.
enum AppTheme { fresh, fall, midnight }

extension AppThemeInfo on AppTheme {
  String get label {
    switch (this) {
      case AppTheme.fresh:
        return 'Fresh';
      case AppTheme.fall:
        return 'Fall';
      case AppTheme.midnight:
        return 'Midnight';
    }
  }
}

/// All user-configurable preferences, persisted locally.
class UserSettings {
  String zip;
  String storeId;
  int householdSize;

  /// Weekday numbers the user cooks on (DateTime.monday == 1 .. sunday == 7).
  List<int> cookNights;

  double weeklyBudget;

  /// Weekday number the user shops on (DateTime.monday == 1 .. sunday == 7).
  int shoppingDay;

  bool twoWeekMode;
  AppTheme theme;
  bool onboarded;

  Set<Diet> diets;

  /// Ingredient ids the household won't eat; recipes using them are skipped.
  Set<String> excludedIngredients;

  /// The specific store location picked (null = chain only, priced at the ZIP).
  StoreLocationRef? storeLocation;

  /// Centroid of [zip], used for metro pricing when no store location is set.
  double? zipLat;
  double? zipLng;

  /// Kitchen gear owned: 'oven', 'slow_cooker', 'air_fryer', 'pressure_cooker',
  /// 'grill'. Recipes needing gear the user lacks are never planned. The stove
  /// is assumed.
  Set<String> equipment;

  /// How many nights a week to plan meals for the special gear (slow cooker,
  /// air fryer, Instant Pot, grill) when the user owns some.
  int gearNights;

  /// Longest hands-on recipe to plan, in minutes (null = any). Slow-cooker
  /// meals cook unattended and are exempt.
  int? maxMinutes;

  bool easyOnly;

  /// Skip recipes with chiles, hot sauce and other heat.
  bool mildOnly;

  UserSettings({
    this.zip = '',
    this.storeId = 'kroger',
    this.householdSize = 4,
    List<int>? cookNights,
    this.weeklyBudget = 100,
    this.shoppingDay = DateTime.sunday,
    this.twoWeekMode = false,
    this.theme = AppTheme.fresh,
    this.onboarded = false,
    Set<Diet>? diets,
    Set<String>? excludedIngredients,
    this.storeLocation,
    this.zipLat,
    this.zipLng,
    Set<String>? equipment,
    this.gearNights = 2,
    this.maxMinutes = 60,
    this.easyOnly = false,
    this.mildOnly = false,
  })  : equipment = equipment ?? {'oven'},
        diets = diets ?? <Diet>{},
        excludedIngredients = excludedIngredients ?? <String>{},
        cookNights = cookNights ??
            [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
            ];

  int get cookNightCount => cookNights.length;

  /// Copies with changes. Changing [zip] drops the old ZIP centroid unless new
  /// coordinates are given; changing [storeId] drops the store location unless
  /// a new one is given or it belongs to the new chain.
  UserSettings copyWith({
    String? zip,
    String? storeId,
    int? householdSize,
    List<int>? cookNights,
    double? weeklyBudget,
    int? shoppingDay,
    bool? twoWeekMode,
    AppTheme? theme,
    bool? onboarded,
    Set<Diet>? diets,
    Set<String>? excludedIngredients,
    StoreLocationRef? storeLocation,
    bool clearStoreLocation = false,
    double? zipLat,
    double? zipLng,
    Set<String>? equipment,
    int? gearNights,
    int? maxMinutes,
    bool clearMaxMinutes = false,
    bool? easyOnly,
    bool? mildOnly,
  }) {
    final zipChanged = zip != null && zip != this.zip;
    final newStoreId = storeId ?? this.storeId;
    var loc = storeLocation ?? this.storeLocation;
    if (clearStoreLocation || (loc != null && loc.storeId != newStoreId)) {
      loc = storeLocation?.storeId == newStoreId ? storeLocation : null;
    }
    return UserSettings(
      zip: zip ?? this.zip,
      storeId: storeId ?? this.storeId,
      householdSize: householdSize ?? this.householdSize,
      cookNights: cookNights ?? List<int>.from(this.cookNights),
      weeklyBudget: weeklyBudget ?? this.weeklyBudget,
      shoppingDay: shoppingDay ?? this.shoppingDay,
      twoWeekMode: twoWeekMode ?? this.twoWeekMode,
      theme: theme ?? this.theme,
      onboarded: onboarded ?? this.onboarded,
      diets: diets ?? Set<Diet>.from(this.diets),
      excludedIngredients:
          excludedIngredients ?? Set<String>.from(this.excludedIngredients),
      storeLocation: loc,
      zipLat: zipLat ?? (zipChanged ? null : this.zipLat),
      zipLng: zipLng ?? (zipChanged ? null : this.zipLng),
      equipment: equipment ?? Set<String>.from(this.equipment),
      gearNights: gearNights ?? this.gearNights,
      maxMinutes: clearMaxMinutes ? null : (maxMinutes ?? this.maxMinutes),
      easyOnly: easyOnly ?? this.easyOnly,
      mildOnly: mildOnly ?? this.mildOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'zip': zip,
        'storeId': storeId,
        'householdSize': householdSize,
        'cookNights': cookNights,
        'weeklyBudget': weeklyBudget,
        'shoppingDay': shoppingDay,
        'twoWeekMode': twoWeekMode,
        'theme': theme.name,
        'onboarded': onboarded,
        'diets': diets.map((d) => d.name).toList(),
        'excludedIngredients': excludedIngredients.toList(),
        'storeLocation': storeLocation?.toJson(),
        'zipLat': zipLat,
        'zipLng': zipLng,
        'equipment': equipment.toList(),
        'gearVersion': 2,
        'gearNights': gearNights,
        'maxMinutes': maxMinutes,
        'easyOnly': easyOnly,
        'mildOnly': mildOnly,
      };

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
        zip: (j['zip'] as String?) ?? '',
        storeId: (j['storeId'] as String?) ?? 'kroger',
        householdSize: (j['householdSize'] as int?) ?? 4,
        cookNights:
            ((j['cookNights'] as List?) ?? []).map((e) => e as int).toList(),
        weeklyBudget: (j['weeklyBudget'] as num?)?.toDouble() ?? 100,
        shoppingDay: (j['shoppingDay'] as int?) ?? DateTime.sunday,
        twoWeekMode: (j['twoWeekMode'] as bool?) ?? false,
        theme: AppTheme.values.firstWhere(
          (t) => t.name == (j['theme'] as String?),
          orElse: () => AppTheme.fresh,
        ),
        onboarded: (j['onboarded'] as bool?) ?? false,
        diets: dietsFromNames((j['diets'] as List?) ?? const []),
        excludedIngredients: ((j['excludedIngredients'] as List?) ?? [])
            .map((e) => e as String)
            .toSet(),
        storeLocation: j['storeLocation'] == null
            ? null
            : StoreLocationRef.fromJson(j['storeLocation'] as Map<String, dynamic>),
        zipLat: (j['zipLat'] as num?)?.toDouble(),
        zipLng: (j['zipLng'] as num?)?.toDouble(),
        equipment: {
          ...((j['equipment'] as List?) ?? []).map((e) => e as String),
          // Before gear version 2 every kitchen was assumed to have an oven.
          if (j['gearVersion'] != 2) 'oven',
        },
        gearNights: (j['gearNights'] as int?) ?? 2,
        // Absent in older versions: default to weeknight-friendly 60 minutes.
        // A saved null means the user chose "Any".
        maxMinutes: j.containsKey('maxMinutes') ? j['maxMinutes'] as int? : 60,
        easyOnly: (j['easyOnly'] as bool?) ?? false,
        mildOnly: (j['mildOnly'] as bool?) ?? false,
      );
}
