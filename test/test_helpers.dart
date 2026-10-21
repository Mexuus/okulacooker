import 'dart:io';

import 'package:okulacooker/data/recipe_db.dart';
import 'package:okulacooker/services/price_book.dart';

/// Loads the bundled recipe database and price book from disk for tests.
void loadTestData() {
  if (!RecipeDb.isLoaded) {
    RecipeDb.instance =
        RecipeDb.fromJsonString(File('assets/data/recipe_db.json').readAsStringSync());
  }
  PriceBook.instance =
      PriceBook.fromJsonString(File('assets/data/prices.json').readAsStringSync());
}
