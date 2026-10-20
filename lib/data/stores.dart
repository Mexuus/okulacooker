import '../models/store.dart';

/// US grocery chains with rough price-positioning multipliers vs. a national
/// reference, approximate state footprints, and keywords for recognising them
/// in OpenStreetMap data. Estimates only — TapCook is not affiliated with any
/// retailer, and store names indicate only which chain a plan was priced
/// against.
const Set<String> _allStates = {
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'HI', 'ID',
  'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO',
  'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA',
  'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
};

final List<Store> kStores = [
  // ---- Discount / warehouse ----
  Store(id: 'aldi', name: 'Aldi', priceMultiplier: 0.85, keywords: ['aldi'],
      states: _allStates.difference(
          {'AK', 'HI', 'MT', 'WY', 'ID', 'OR', 'WA', 'NV', 'UT', 'NM'})),
  const Store(id: 'winco', name: 'WinCo Foods', priceMultiplier: 0.86, keywords: ['winco'],
      states: {'WA', 'OR', 'ID', 'CA', 'NV', 'UT', 'AZ', 'TX', 'OK', 'MT'}),
  const Store(id: 'lidl', name: 'Lidl', priceMultiplier: 0.88, keywords: ['lidl'],
      states: {'NY', 'NJ', 'PA', 'DE', 'MD', 'VA', 'NC', 'SC', 'GA', 'DC'}),
  const Store(id: 'food_4_less', name: 'Food 4 Less', priceMultiplier: 0.88,
      keywords: ['food 4 less', 'food4less', 'foods co'], states: {'CA', 'NV', 'IL', 'IN'}),
  const Store(id: 'foodmaxx', name: 'FoodMaxx', priceMultiplier: 0.88, keywords: ['foodmaxx'],
      states: {'CA', 'NV'}),
  const Store(id: 'sams_club', name: "Sam's Club", priceMultiplier: 0.89,
      keywords: ["sam's club", 'sams club']),
  const Store(id: 'costco', name: 'Costco', priceMultiplier: 0.90, keywords: ['costco']),
  const Store(id: 'bjs', name: "BJ's Wholesale", priceMultiplier: 0.91,
      keywords: ["bj's wholesale", 'bjs wholesale', "bj's"],
      states: {'MA', 'NY', 'NJ', 'PA', 'CT', 'ME', 'NH', 'RI', 'DE', 'MD', 'VA',
               'NC', 'SC', 'GA', 'FL', 'OH', 'MI'}),
  const Store(id: 'walmart', name: 'Walmart', priceMultiplier: 0.92, keywords: ['walmart']),
  const Store(id: 'market_basket', name: 'Market Basket', priceMultiplier: 0.93,
      keywords: ['market basket'], states: {'MA', 'NH', 'ME'}),

  // ---- Conventional ----
  const Store(id: 'heb', name: 'H-E-B', priceMultiplier: 0.95, keywords: ['h-e-b', 'heb'],
      states: {'TX'}),
  const Store(id: 'meijer', name: 'Meijer', priceMultiplier: 0.97, keywords: ['meijer'],
      states: {'MI', 'OH', 'IN', 'IL', 'KY', 'WI'}),
  const Store(id: 'smart_final', name: 'Smart & Final', priceMultiplier: 0.97,
      keywords: ['smart & final', 'smart and final'], states: {'CA', 'AZ', 'NV'}),
  const Store(id: 'food_lion', name: 'Food Lion', priceMultiplier: 0.98, keywords: ['food lion'],
      states: {'NC', 'SC', 'VA', 'GA', 'TN', 'MD', 'DE', 'WV'}),
  const Store(id: 'stater_bros', name: 'Stater Bros.', priceMultiplier: 0.98,
      keywords: ['stater bros', 'stater brothers'], states: {'CA'}),
  const Store(id: 'dillons', name: 'Dillons', priceMultiplier: 0.98, keywords: ['dillons'],
      states: {'KS'}),
  const Store(id: 'frys', name: "Fry's Food", priceMultiplier: 0.99,
      keywords: ["fry's food", 'frys food', "fry's marketplace"], states: {'AZ'}),
  const Store(id: 'kroger', name: 'Kroger', priceMultiplier: 1.00, keywords: ['kroger'],
      states: {'AL', 'AR', 'GA', 'IL', 'IN', 'KY', 'LA', 'MI', 'MS', 'NC', 'OH', 'SC',
               'TN', 'TX', 'VA', 'WV'}),
  const Store(id: 'king_soopers', name: 'King Soopers', priceMultiplier: 1.00,
      keywords: ['king soopers', 'city market'], states: {'CO', 'WY'}),
  const Store(id: 'smiths', name: "Smith's", priceMultiplier: 1.00,
      keywords: ["smith's food", 'smiths food', "smith's marketplace"],
      states: {'UT', 'NV', 'NM', 'ID', 'WY', 'MT'}),
  const Store(id: 'winn_dixie', name: 'Winn-Dixie', priceMultiplier: 1.00,
      keywords: ['winn-dixie', 'winn dixie'], states: {'FL', 'GA', 'AL', 'MS', 'LA'}),
  const Store(id: 'ingles', name: 'Ingles', priceMultiplier: 1.00, keywords: ['ingles'],
      states: {'NC', 'SC', 'GA', 'TN', 'VA', 'AL'}),
  const Store(id: 'trader_joes', name: "Trader Joe's", priceMultiplier: 1.00,
      keywords: ["trader joe's", 'trader joes']),
  const Store(id: 'pick_n_save', name: "Pick 'n Save", priceMultiplier: 1.00,
      keywords: ["pick 'n save", 'pick n save', 'metro market'], states: {'WI'}),
  const Store(id: 'fred_meyer', name: 'Fred Meyer', priceMultiplier: 1.02,
      keywords: ['fred meyer'], states: {'OR', 'WA', 'ID', 'AK'}),
  const Store(id: 'shoprite', name: 'ShopRite', priceMultiplier: 1.02,
      keywords: ['shoprite', 'shop rite'], states: {'NJ', 'NY', 'PA', 'CT', 'DE', 'MD'}),
  const Store(id: 'weis', name: 'Weis Markets', priceMultiplier: 1.02, keywords: ['weis'],
      states: {'PA', 'MD', 'NJ', 'NY', 'DE', 'VA', 'WV'}),
  const Store(id: 'piggly_wiggly', name: 'Piggly Wiggly', priceMultiplier: 1.02,
      keywords: ['piggly wiggly'],
      states: {'AL', 'GA', 'SC', 'NC', 'TN', 'MS', 'WI', 'VA', 'KY'}),
  const Store(id: 'target', name: 'Target', priceMultiplier: 1.03, keywords: ['target']),
  const Store(id: 'hy_vee', name: 'Hy-Vee', priceMultiplier: 1.03, keywords: ['hy-vee', 'hyvee'],
      states: {'IA', 'MN', 'MO', 'NE', 'KS', 'SD', 'IL', 'WI'}),
  const Store(id: 'tops', name: 'Tops', priceMultiplier: 1.03, keywords: ['tops'],
      states: {'NY', 'PA', 'VT'}),
  const Store(id: 'price_chopper', name: 'Price Chopper / Market 32', priceMultiplier: 1.03,
      keywords: ['price chopper', 'market 32'],
      states: {'NY', 'VT', 'MA', 'CT', 'PA', 'NH'}),
  const Store(id: 'giant_eagle', name: 'Giant Eagle', priceMultiplier: 1.04,
      keywords: ['giant eagle'], states: {'PA', 'OH', 'WV', 'MD', 'IN'}),
  const Store(id: 'hannaford', name: 'Hannaford', priceMultiplier: 1.04, keywords: ['hannaford'],
      states: {'ME', 'NH', 'VT', 'MA', 'NY'}),
  const Store(id: 'publix', name: 'Publix', priceMultiplier: 1.05, keywords: ['publix'],
      states: {'FL', 'GA', 'AL', 'SC', 'NC', 'TN', 'VA', 'KY'}),
  const Store(id: 'giant', name: 'Giant', priceMultiplier: 1.05,
      keywords: ['giant food', 'giant'], states: {'PA', 'MD', 'VA', 'DE', 'DC', 'WV'}),
  const Store(id: 'save_mart', name: 'Save Mart', priceMultiplier: 1.05, keywords: ['save mart'],
      states: {'CA', 'NV'}),
  const Store(id: 'lucky', name: 'Lucky', priceMultiplier: 1.04, keywords: ['lucky'],
      states: {'CA'}),
  const Store(id: 'marianos', name: "Mariano's", priceMultiplier: 1.06,
      keywords: ["mariano's", 'marianos'], states: {'IL'}),
  const Store(id: 'qfc', name: 'QFC', priceMultiplier: 1.07, keywords: ['qfc'],
      states: {'WA', 'OR'}),
  const Store(id: 'tom_thumb', name: 'Tom Thumb', priceMultiplier: 1.07, keywords: ['tom thumb'],
      states: {'TX'}),
  const Store(id: 'randalls', name: 'Randalls', priceMultiplier: 1.07, keywords: ['randalls'],
      states: {'TX'}),
  const Store(id: 'star_market', name: 'Star Market', priceMultiplier: 1.08,
      keywords: ['star market'], states: {'MA'}),
  const Store(id: 'pavilions', name: 'Pavilions', priceMultiplier: 1.10, keywords: ['pavilions'],
      states: {'CA'}),
  const Store(id: 'wegmans', name: 'Wegmans', priceMultiplier: 1.06, keywords: ['wegmans'],
      states: {'NY', 'PA', 'NJ', 'MA', 'MD', 'VA', 'NC', 'DE', 'CT', 'DC'}),
  const Store(id: 'jewel_osco', name: 'Jewel-Osco', priceMultiplier: 1.06,
      keywords: ['jewel-osco', 'jewel osco', 'jewel'], states: {'IL', 'IN', 'IA'}),
  const Store(id: 'albertsons', name: 'Albertsons', priceMultiplier: 1.07,
      keywords: ['albertsons'],
      states: {'AZ', 'CA', 'ID', 'LA', 'MT', 'NV', 'NM', 'OR', 'TX', 'UT', 'WA', 'WY'}),
  const Store(id: 'stop_shop', name: 'Stop & Shop', priceMultiplier: 1.07,
      keywords: ['stop & shop', 'stop and shop'], states: {'MA', 'CT', 'RI', 'NY', 'NJ'}),
  const Store(id: 'safeway', name: 'Safeway', priceMultiplier: 1.08, keywords: ['safeway'],
      states: {'CA', 'OR', 'WA', 'AK', 'HI', 'AZ', 'CO', 'ID', 'MT', 'NE', 'NM', 'NV',
               'SD', 'WY', 'DC', 'MD', 'VA', 'DE'}),
  const Store(id: 'vons', name: 'Vons', priceMultiplier: 1.08, keywords: ['vons'],
      states: {'CA', 'NV'}),
  const Store(id: 'ralphs', name: 'Ralphs', priceMultiplier: 1.08, keywords: ['ralphs'],
      states: {'CA'}),
  const Store(id: 'harris_teeter', name: 'Harris Teeter', priceMultiplier: 1.08,
      keywords: ['harris teeter'], states: {'NC', 'SC', 'VA', 'MD', 'DE', 'DC', 'GA', 'FL'}),
  const Store(id: 'acme', name: 'Acme Markets', priceMultiplier: 1.08, keywords: ['acme'],
      states: {'PA', 'NJ', 'DE', 'MD', 'NY', 'CT'}),
  const Store(id: 'shaws', name: "Shaw's", priceMultiplier: 1.08, keywords: ["shaw's", 'shaws'],
      states: {'MA', 'NH', 'ME', 'VT', 'RI'}),
  const Store(id: 'raleys', name: "Raley's", priceMultiplier: 1.10, keywords: ["raley's", 'raleys'],
      states: {'CA', 'NV'}),

  // ---- Premium ----
  const Store(id: 'sprouts', name: 'Sprouts', priceMultiplier: 1.15, keywords: ['sprouts'],
      states: {'AZ', 'CA', 'CO', 'TX', 'NV', 'NM', 'UT', 'OK', 'GA', 'FL', 'NC', 'SC', 'VA',
               'MD', 'PA', 'NJ', 'DE', 'AL', 'TN', 'KS', 'MO', 'WA', 'LA'}),
  const Store(id: 'whole_foods', name: 'Whole Foods', priceMultiplier: 1.35,
      keywords: ['whole foods']),
];

Store storeById(String id) => kStores.firstWhere(
      (s) => s.id == id,
      orElse: () => kStores.firstWhere((s) => s.id == 'kroger'),
    );

/// Chains sorted with those operating in [state] first, then alphabetically.
List<Store> storesForState(String? state) {
  final list = [...kStores]..sort((a, b) {
      final ai = a.operatesIn(state) ? 0 : 1;
      final bi = b.operatesIn(state) ? 0 : 1;
      if (ai != bi) return ai - bi;
      return a.name.compareTo(b.name);
    });
  return list;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r'\s+'), ' ').trim();

/// Matches free-text map data (brand / name) to a known chain. Longest keyword
/// wins so e.g. "Giant Eagle" isn't mistaken for "Giant".
Store? matchStore(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final t = _normalize(text);
  Store? best;
  var bestLen = 0;
  for (final s in kStores) {
    for (final k in s.keywords) {
      if (k.length <= bestLen) continue;
      final re = RegExp('(^|[^a-z0-9])${RegExp.escape(k)}(\$|[^a-z0-9])');
      if (re.hasMatch(t)) {
        best = s;
        bestLen = k.length;
      }
    }
  }
  return best;
}
