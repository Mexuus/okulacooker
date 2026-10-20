/// One ingredient line in a recipe (amount in the recipe's own unit).
class RecipeIngredient {
  final String ingredientId;
  final double amount;
  final String unit; // lb, oz, cup, tbsp, tsp, count, clove, stalk, packet

  const RecipeIngredient(this.ingredientId, this.amount, this.unit);

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        j['canonical_id'] as String,
        (j['amount'] as num).toDouble(),
        j['unit'] as String,
      );
}

/// A scalable amount embedded in a direction step as `{n}`.
///
/// Kinds (`k`): null/`lin` = scales with servings; `ref`/`all`/`of` = textual
/// references to an ingredient ("the onion", "both cans"); `per` = per-person
/// amount that doesn't scale.
class StepAmount {
  final String cid;
  final double value;
  final double? value2; // upper bound of a range ("2-3 tbsp")
  final String? unit;
  final String? width; // "short" (tbsp) or "long" (tablespoons)
  final String? kind;
  final List<String>? nouns; // [singular, plural]
  final List<String>? forms; // [form when 1, form when many] e.g. ["a bowl", "{n} bowls"]
  final String base; // exact text at the recipe's base servings

  const StepAmount({
    required this.cid,
    required this.value,
    required this.base,
    this.value2,
    this.unit,
    this.width,
    this.kind,
    this.nouns,
    this.forms,
  });

  factory StepAmount.fromJson(Map<String, dynamic> j) {
    List<String>? strs(Object? o) => o is List ? o.map((e) => e.toString()).toList() : null;
    return StepAmount(
      cid: j['cid'] as String,
      value: (j['v'] as num).toDouble(),
      value2: (j['v2'] as num?)?.toDouble(),
      unit: j['u'] as String?,
      width: j['w'] as String?,
      kind: j['k'] as String?,
      nouns: strs(j['n']),
      forms: strs(j['f']),
      base: j['b'] as String,
    );
  }
}

class RecipeAction {
  final String verb;
  final String body; // may contain {0}, {1}… placeholders for [amounts]
  final String? duration;
  final List<StepAmount> amounts;

  const RecipeAction({
    required this.verb,
    required this.body,
    this.duration,
    this.amounts = const [],
  });

  factory RecipeAction.fromJson(Map<String, dynamic> j) => RecipeAction(
        verb: j['verb'] as String,
        body: j['body'] as String,
        duration: j['duration'] as String?,
        amounts: ((j['amounts'] as List?) ?? [])
            .map((a) => StepAmount.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class RecipePhase {
  final String name;
  final int minutes;
  final List<RecipeAction> actions;

  const RecipePhase({required this.name, required this.minutes, required this.actions});

  factory RecipePhase.fromJson(Map<String, dynamic> j) => RecipePhase(
        name: j['phase'] as String,
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        actions: (j['actions'] as List)
            .map((a) => RecipeAction.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

/// A dinner recipe from the recipe database.
class Recipe {
  final String id;
  final String title;
  final String cuisine;

  /// Main ingredient (e.g. "chicken_thigh_boneless") — used for variety.
  final String anchor;
  final int baseServings;
  final int totalMinutes;
  final String format; // skillet, oven, pot, slow, air
  final String equipment; // stove, oven, slow_cooker, air_fryer
  final List<RecipeIngredient> ingredients;
  final double costPerServing; // reference cost from the database
  final List<RecipePhase> phases;
  final String difficulty;
  final int cleanupScore;

  /// App version the recipe was added in (null = original set).
  final String? addedIn;

  const Recipe({
    required this.id,
    required this.title,
    required this.cuisine,
    required this.anchor,
    required this.baseServings,
    required this.totalMinutes,
    required this.format,
    required this.equipment,
    required this.ingredients,
    required this.costPerServing,
    required this.phases,
    required this.difficulty,
    required this.cleanupScore,
    this.addedIn,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: '${j['id']}',
        title: j['title'] as String,
        cuisine: j['cuisine'] as String,
        anchor: j['anchor'] as String,
        baseServings: (j['serves'] as num).toInt(),
        totalMinutes: (j['minutes'] as num).toInt(),
        format: j['format'] as String,
        equipment: j['equipment'] as String,
        ingredients: (j['ingredients'] as List)
            .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
            .toList(),
        costPerServing: (j['cost_per_serving'] as num).toDouble(),
        phases: (j['directions'] as List)
            .map((p) => RecipePhase.fromJson(p as Map<String, dynamic>))
            .toList(),
        difficulty: j['difficulty'] as String,
        cleanupScore: (j['cleanup_score'] as num).toInt(),
        addedIn: j['added'] as String?,
      );

  String get formatLabel => const {
        'skillet': 'Skillet',
        'oven': 'Oven',
        'pot': 'One pot',
        'slow': 'Slow cooker',
        'air': 'Air fryer',
      }[format] ??
      format;

  List<String> get tags => [cuisine, difficulty, formatLabel];

  /// Emoji "photo" for the dish, from its title, then main ingredient, then cuisine.
  String get emoji {
    final t = title.toLowerCase();
    const byTitle = [
      ('taco', '🌮'), ('burrito', '🌯'), ('wrap', '🌯'), ('quesadilla', '🫓'),
      ('burger', '🍔'), ('pizza', '🍕'), ('flatbread', '🍕'), ('sandwich', '🥪'),
      ('curry', '🍛'), ('masala', '🍛'), ('dal', '🍛'), ('soup', '🍲'), ('stew', '🍲'),
      ('chili', '🌶️'), ('salad', '🥗'), ('ramen', '🍜'), ('noodle', '🍜'), ('pho', '🍜'),
      ('lo mein', '🍜'), ('pad thai', '🍜'), ('fried rice', '🍚'), ('bowl', '🍚'),
      ('risotto', '🍚'), ('lasagna', '🍝'), ('spaghetti', '🍝'), ('pasta', '🍝'),
      ('gnocchi', '🍝'), ('orzo', '🍝'), ('frittata', '🍳'), ('shakshuka', '🍳'),
      ('omelet', '🍳'), ('dumpling', '🥟'), ('skewer', '🍢'), ('kebab', '🍢'),
      ('pie', '🥧'), ('hash', '🥔'),
    ];
    for (final (k, e) in byTitle) {
      if (RegExp('\\b${RegExp.escape(k)}(s|es)?\\b').hasMatch(t)) return e;
    }
    final a = anchor;
    const byAnchor = [
      ('chicken', '🍗'), ('turkey', '🦃'), ('beef', '🥩'), ('steak', '🥩'),
      ('lamb', '🍖'), ('pork', '🍖'), ('bacon', '🥓'), ('pancetta', '🥓'),
      ('sausage', '🌭'), ('salmon', '🐟'), ('tilapia', '🐟'), ('shrimp', '🍤'),
      ('tofu', '🥢'), ('tempeh', '🥢'), ('eggplant', '🍆'), ('egg', '🍳'), ('bean', '🫘'),
      ('lentil', '🫘'), ('chickpea', '🫘'), ('mushroom', '🍄'), ('potato', '🥔'),
      ('cauliflower', '🥦'), ('squash', '🎃'), ('pasta', '🍝'), ('gnocchi', '🍝'),
      ('noodle', '🍜'),
    ];
    for (final (k, e) in byAnchor) {
      if (a.contains(k)) return e;
    }
    return const {
          'Mexican': '🌮', 'Tex-Mex': '🌮', 'Italian': '🍝', 'Chinese': '🥡',
          'Japanese': '🍱', 'Indian': '🍛', 'Thai': '🍜', 'Korean': '🍲',
          'Greek': '🥙', 'Mediterranean': '🥙', 'Middle Eastern': '🥙',
        }[cuisine] ??
        '🍽️';
  }
}
