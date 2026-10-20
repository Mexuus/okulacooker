/// Something frozen from a previous week's extra servings, available to cover a
/// future dinner instead of re-buying ingredients (smarter leftovers).
class FreezerItem {
  final String id;
  final String recipeId;
  final int servings;

  /// ISO date the item was frozen.
  final String frozenOn;

  FreezerItem({
    required this.id,
    required this.recipeId,
    required this.servings,
    required this.frozenOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'servings': servings,
        'frozenOn': frozenOn,
      };

  factory FreezerItem.fromJson(Map<String, dynamic> j) => FreezerItem(
        id: j['id'] as String,
        recipeId: j['recipeId'] as String,
        servings: j['servings'] as int,
        frozenOn: j['frozenOn'] as String,
      );
}

/// Persistent pantry state: the set of staple ingredient ids the user already
/// owns. These are removed from the bill this week and every week after, until
/// unticked.
class PantryState {
  final Set<String> ownedStapleIds;

  PantryState({Set<String>? ownedStapleIds})
      : ownedStapleIds = ownedStapleIds ?? <String>{};

  Map<String, dynamic> toJson() => {
        'ownedStapleIds': ownedStapleIds.toList(),
      };

  factory PantryState.fromJson(Map<String, dynamic> j) => PantryState(
        ownedStapleIds:
            ((j['ownedStapleIds'] as List?) ?? []).map((e) => e as String).toSet(),
      );
}
