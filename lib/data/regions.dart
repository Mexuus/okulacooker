import '../models/store.dart';
import 'zip_states.dart';

/// U.S. Census regions — the geography BLS publishes average prices for.
const Region kNationalRegion = Region(id: 'US', name: 'National average');
const Map<String, Region> kCensusRegions = {
  'NE': Region(id: 'NE', name: 'Northeast'),
  'MW': Region(id: 'MW', name: 'Midwest'),
  'S': Region(id: 'S', name: 'South'),
  'W': Region(id: 'W', name: 'West'),
};

const Map<String, String> _stateRegion = {
  // Northeast
  'CT': 'NE', 'ME': 'NE', 'MA': 'NE', 'NH': 'NE', 'RI': 'NE', 'VT': 'NE',
  'NJ': 'NE', 'NY': 'NE', 'PA': 'NE',
  // Midwest
  'IL': 'MW', 'IN': 'MW', 'MI': 'MW', 'OH': 'MW', 'WI': 'MW', 'IA': 'MW',
  'KS': 'MW', 'MN': 'MW', 'MO': 'MW', 'NE': 'MW', 'ND': 'MW', 'SD': 'MW',
  // South
  'DE': 'S', 'DC': 'S', 'FL': 'S', 'GA': 'S', 'MD': 'S', 'NC': 'S', 'SC': 'S',
  'VA': 'S', 'WV': 'S', 'AL': 'S', 'KY': 'S', 'MS': 'S', 'TN': 'S', 'AR': 'S',
  'LA': 'S', 'OK': 'S', 'TX': 'S',
  // West
  'AZ': 'W', 'CO': 'W', 'ID': 'W', 'MT': 'W', 'NV': 'W', 'NM': 'W', 'UT': 'W',
  'WY': 'W', 'AK': 'W', 'CA': 'W', 'HI': 'W', 'OR': 'W', 'WA': 'W',
};

/// Census region for a two-letter state code; national average if unknown.
Region regionForState(String? state) =>
    kCensusRegions[_stateRegion[state]] ?? kNationalRegion;

/// Census region for a ZIP code (via its state).
Region regionForZip(String zip) => regionForState(stateForZip(zip));

/// Basic validity check for a US 5-digit ZIP.
bool isValidZip(String zip) => RegExp(r'^\d{5}$').hasMatch(zip.trim());
