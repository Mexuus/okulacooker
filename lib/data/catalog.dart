import '../models/ingredient.dart';

/// Master ingredient catalog keyed by id. Prices are flat *national reference*
/// estimates in USD per listed unit. Staples (oils, spices, basic condiments)
/// are flagged so users can tick off what they already own.
const Map<String, Ingredient> kIngredients = {
  // ---- Produce ----
  'onion': Ingredient(id: 'onion', name: 'Onion', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.70),
  'garlic': Ingredient(id: 'garlic', name: 'Garlic', aisle: Aisle.produce, unit: 'clove', refPricePerUnit: 0.12),
  'bell_pepper': Ingredient(id: 'bell_pepper', name: 'Bell pepper', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 1.10),
  'tomato': Ingredient(id: 'tomato', name: 'Tomato', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.80),
  'roma_tomato': Ingredient(id: 'roma_tomato', name: 'Roma tomato', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.55),
  'romaine': Ingredient(id: 'romaine', name: 'Romaine lettuce', aisle: Aisle.produce, unit: 'head', refPricePerUnit: 1.80),
  'lemon': Ingredient(id: 'lemon', name: 'Lemon', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.60),
  'lime': Ingredient(id: 'lime', name: 'Lime', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.40),
  'potato': Ingredient(id: 'potato', name: 'Potatoes', aisle: Aisle.produce, unit: 'lb', refPricePerUnit: 0.95),
  'sweet_potato': Ingredient(id: 'sweet_potato', name: 'Sweet potato', aisle: Aisle.produce, unit: 'lb', refPricePerUnit: 1.30),
  'broccoli': Ingredient(id: 'broccoli', name: 'Broccoli', aisle: Aisle.produce, unit: 'lb', refPricePerUnit: 1.90),
  'carrot': Ingredient(id: 'carrot', name: 'Carrots', aisle: Aisle.produce, unit: 'lb', refPricePerUnit: 0.90),
  'zucchini': Ingredient(id: 'zucchini', name: 'Zucchini', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.90),
  'mushroom': Ingredient(id: 'mushroom', name: 'Mushrooms', aisle: Aisle.produce, unit: 'oz', refPricePerUnit: 0.30),
  'spinach': Ingredient(id: 'spinach', name: 'Baby spinach', aisle: Aisle.produce, unit: 'oz', refPricePerUnit: 0.38),
  'cilantro': Ingredient(id: 'cilantro', name: 'Cilantro', aisle: Aisle.produce, unit: 'bunch', refPricePerUnit: 0.80),
  'green_onion': Ingredient(id: 'green_onion', name: 'Green onions', aisle: Aisle.produce, unit: 'bunch', refPricePerUnit: 0.90),
  'avocado': Ingredient(id: 'avocado', name: 'Avocado', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 1.20),
  'ginger': Ingredient(id: 'ginger', name: 'Fresh ginger', aisle: Aisle.produce, unit: 'oz', refPricePerUnit: 0.50),
  'jalapeno': Ingredient(id: 'jalapeno', name: 'Jalapeño', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.30),
  'snap_peas': Ingredient(id: 'snap_peas', name: 'Snap peas', aisle: Aisle.produce, unit: 'oz', refPricePerUnit: 0.42),
  'cucumber': Ingredient(id: 'cucumber', name: 'Cucumber', aisle: Aisle.produce, unit: 'each', refPricePerUnit: 0.80),
  'celery': Ingredient(id: 'celery', name: 'Celery', aisle: Aisle.produce, unit: 'stalk', refPricePerUnit: 0.20),
  'coleslaw_mix': Ingredient(id: 'coleslaw_mix', name: 'Coleslaw mix', aisle: Aisle.produce, unit: 'oz', refPricePerUnit: 0.22),
  'tofu': Ingredient(id: 'tofu', name: 'Firm tofu (14 oz)', aisle: Aisle.produce, unit: 'block', refPricePerUnit: 2.20),

  // ---- Meat ----
  'ground_beef': Ingredient(id: 'ground_beef', name: 'Ground beef', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 5.20),
  'ground_turkey': Ingredient(id: 'ground_turkey', name: 'Ground turkey', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 4.80),
  'chicken_breast': Ingredient(id: 'chicken_breast', name: 'Chicken breast', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 3.90),
  'chicken_thigh': Ingredient(id: 'chicken_thigh', name: 'Chicken thighs', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 2.80),
  'pork_chop': Ingredient(id: 'pork_chop', name: 'Pork chops', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 4.20),
  'pork_shoulder': Ingredient(id: 'pork_shoulder', name: 'Pork shoulder', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 3.20),
  'bacon': Ingredient(id: 'bacon', name: 'Bacon', aisle: Aisle.meat, unit: 'oz', refPricePerUnit: 0.55),
  'italian_sausage': Ingredient(id: 'italian_sausage', name: 'Italian sausage', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 4.50),
  'flank_steak': Ingredient(id: 'flank_steak', name: 'Flank steak', aisle: Aisle.meat, unit: 'lb', refPricePerUnit: 9.00),

  // ---- Seafood ----
  'salmon': Ingredient(id: 'salmon', name: 'Salmon fillet', aisle: Aisle.seafood, unit: 'lb', refPricePerUnit: 11.00),
  'shrimp': Ingredient(id: 'shrimp', name: 'Shrimp', aisle: Aisle.seafood, unit: 'lb', refPricePerUnit: 9.50),
  'tilapia': Ingredient(id: 'tilapia', name: 'Tilapia fillets', aisle: Aisle.seafood, unit: 'lb', refPricePerUnit: 6.50),
  'tuna_can': Ingredient(id: 'tuna_can', name: 'Canned tuna (5 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 1.20),

  // ---- Dairy ----
  'milk': Ingredient(id: 'milk', name: 'Milk', aisle: Aisle.dairy, unit: 'cup', refPricePerUnit: 0.18),
  'butter': Ingredient(id: 'butter', name: 'Butter', aisle: Aisle.dairy, unit: 'tbsp', refPricePerUnit: 0.12, staple: true),
  'egg': Ingredient(id: 'egg', name: 'Eggs', aisle: Aisle.dairy, unit: 'each', refPricePerUnit: 0.28),
  'cheddar': Ingredient(id: 'cheddar', name: 'Cheddar cheese', aisle: Aisle.dairy, unit: 'oz', refPricePerUnit: 0.45),
  'mozzarella': Ingredient(id: 'mozzarella', name: 'Mozzarella', aisle: Aisle.dairy, unit: 'oz', refPricePerUnit: 0.50),
  'parmesan': Ingredient(id: 'parmesan', name: 'Parmesan', aisle: Aisle.dairy, unit: 'oz', refPricePerUnit: 0.85),
  'sour_cream': Ingredient(id: 'sour_cream', name: 'Sour cream', aisle: Aisle.dairy, unit: 'oz', refPricePerUnit: 0.20),
  'greek_yogurt': Ingredient(id: 'greek_yogurt', name: 'Greek yogurt', aisle: Aisle.dairy, unit: 'oz', refPricePerUnit: 0.22),
  'heavy_cream': Ingredient(id: 'heavy_cream', name: 'Heavy cream', aisle: Aisle.dairy, unit: 'cup', refPricePerUnit: 1.10),
  'feta': Ingredient(id: 'feta', name: 'Feta cheese', aisle: Aisle.dairy, unit: 'oz', refPricePerUnit: 0.55),

  // ---- Bakery ----
  'tortilla': Ingredient(id: 'tortilla', name: 'Tortillas', aisle: Aisle.bakery, unit: 'each', refPricePerUnit: 0.30),
  'burger_bun': Ingredient(id: 'burger_bun', name: 'Burger buns', aisle: Aisle.bakery, unit: 'each', refPricePerUnit: 0.55),
  'sandwich_roll': Ingredient(id: 'sandwich_roll', name: 'Sandwich rolls', aisle: Aisle.bakery, unit: 'each', refPricePerUnit: 0.60),
  'flatbread': Ingredient(id: 'flatbread', name: 'Flatbread', aisle: Aisle.bakery, unit: 'each', refPricePerUnit: 1.20),
  'wrap_large': Ingredient(id: 'wrap_large', name: 'Large wraps', aisle: Aisle.bakery, unit: 'each', refPricePerUnit: 0.45),
  'pita': Ingredient(id: 'pita', name: 'Pita bread', aisle: Aisle.bakery, unit: 'each', refPricePerUnit: 0.50),

  // ---- Frozen ----
  'frozen_peas': Ingredient(id: 'frozen_peas', name: 'Frozen peas', aisle: Aisle.frozen, unit: 'cup', refPricePerUnit: 0.60),

  // ---- Grains & Pasta ----
  'spaghetti': Ingredient(id: 'spaghetti', name: 'Spaghetti', aisle: Aisle.grains, unit: 'oz', refPricePerUnit: 0.12),
  'penne': Ingredient(id: 'penne', name: 'Penne', aisle: Aisle.grains, unit: 'oz', refPricePerUnit: 0.12),
  'fettuccine': Ingredient(id: 'fettuccine', name: 'Fettuccine', aisle: Aisle.grains, unit: 'oz', refPricePerUnit: 0.13),
  'rice_white': Ingredient(id: 'rice_white', name: 'White rice', aisle: Aisle.grains, unit: 'cup', refPricePerUnit: 0.25),
  'rice_jasmine': Ingredient(id: 'rice_jasmine', name: 'Jasmine rice', aisle: Aisle.grains, unit: 'cup', refPricePerUnit: 0.30),
  'breadcrumbs': Ingredient(id: 'breadcrumbs', name: 'Breadcrumbs', aisle: Aisle.grains, unit: 'cup', refPricePerUnit: 0.60),
  'egg_noodles': Ingredient(id: 'egg_noodles', name: 'Egg noodles', aisle: Aisle.grains, unit: 'oz', refPricePerUnit: 0.16),
  'lentils': Ingredient(id: 'lentils', name: 'Dry lentils', aisle: Aisle.grains, unit: 'cup', refPricePerUnit: 0.55),
  'flour': Ingredient(id: 'flour', name: 'Flour', aisle: Aisle.pantry, unit: 'cup', refPricePerUnit: 0.15, staple: true),

  // ---- Canned ----
  'black_beans': Ingredient(id: 'black_beans', name: 'Black beans (15 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 1.00),
  'kidney_beans': Ingredient(id: 'kidney_beans', name: 'Kidney beans (15 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 1.00),
  'diced_tomatoes': Ingredient(id: 'diced_tomatoes', name: 'Diced tomatoes (14 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 1.10),
  'tomato_sauce': Ingredient(id: 'tomato_sauce', name: 'Tomato sauce (15 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 0.95),
  'pasta_sauce': Ingredient(id: 'pasta_sauce', name: 'Pasta sauce (24 oz)', aisle: Aisle.canned, unit: 'jar', refPricePerUnit: 2.40),
  'coconut_milk': Ingredient(id: 'coconut_milk', name: 'Coconut milk (13 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 1.80),
  'corn_can': Ingredient(id: 'corn_can', name: 'Corn (15 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 0.90),
  'chickpeas': Ingredient(id: 'chickpeas', name: 'Chickpeas (15 oz)', aisle: Aisle.canned, unit: 'can', refPricePerUnit: 1.00),
  'chicken_broth': Ingredient(id: 'chicken_broth', name: 'Chicken broth', aisle: Aisle.canned, unit: 'cup', refPricePerUnit: 0.40),
  'veg_broth': Ingredient(id: 'veg_broth', name: 'Vegetable broth', aisle: Aisle.canned, unit: 'cup', refPricePerUnit: 0.40),
  'pesto': Ingredient(id: 'pesto', name: 'Basil pesto', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.35),

  // ---- Condiments & Spices (mostly staples) ----
  'olive_oil': Ingredient(id: 'olive_oil', name: 'Olive oil', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.10, staple: true),
  'veg_oil': Ingredient(id: 'veg_oil', name: 'Vegetable oil', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.06, staple: true),
  'soy_sauce': Ingredient(id: 'soy_sauce', name: 'Soy sauce', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.10, staple: true),
  'teriyaki': Ingredient(id: 'teriyaki', name: 'Teriyaki sauce', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.14),
  'bbq_sauce': Ingredient(id: 'bbq_sauce', name: 'BBQ sauce', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.12),
  'honey': Ingredient(id: 'honey', name: 'Honey', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.15, staple: true),
  'ketchup': Ingredient(id: 'ketchup', name: 'Ketchup', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.05, staple: true),
  'mayo': Ingredient(id: 'mayo', name: 'Mayonnaise', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.08, staple: true),
  'caesar_dressing': Ingredient(id: 'caesar_dressing', name: 'Caesar dressing', aisle: Aisle.condiments, unit: 'tbsp', refPricePerUnit: 0.18),
  'cornstarch': Ingredient(id: 'cornstarch', name: 'Cornstarch', aisle: Aisle.pantry, unit: 'tbsp', refPricePerUnit: 0.05, staple: true),
  'sesame_oil': Ingredient(id: 'sesame_oil', name: 'Sesame oil', aisle: Aisle.condiments, unit: 'tsp', refPricePerUnit: 0.08, staple: true),
  'salt': Ingredient(id: 'salt', name: 'Salt', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.01, staple: true),
  'pepper': Ingredient(id: 'pepper', name: 'Black pepper', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.03, staple: true),
  'cumin': Ingredient(id: 'cumin', name: 'Cumin', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.05, staple: true),
  'chili_powder': Ingredient(id: 'chili_powder', name: 'Chili powder', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.05, staple: true),
  'paprika': Ingredient(id: 'paprika', name: 'Paprika', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.05, staple: true),
  'garlic_powder': Ingredient(id: 'garlic_powder', name: 'Garlic powder', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.04, staple: true),
  'italian_seasoning': Ingredient(id: 'italian_seasoning', name: 'Italian seasoning', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.05, staple: true),
  'curry_powder': Ingredient(id: 'curry_powder', name: 'Curry powder', aisle: Aisle.spices, unit: 'tsp', refPricePerUnit: 0.06, staple: true),
  'taco_seasoning': Ingredient(id: 'taco_seasoning', name: 'Taco seasoning', aisle: Aisle.spices, unit: 'packet', refPricePerUnit: 0.90),
  'sugar': Ingredient(id: 'sugar', name: 'Sugar', aisle: Aisle.pantry, unit: 'tsp', refPricePerUnit: 0.01, staple: true),
};

Ingredient ingredientById(String id) =>
    kIngredients[id] ??
    (throw ArgumentError('Unknown ingredient id: $id'));
