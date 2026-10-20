import '../models/store.dart';

/// Maps a US ZIP code to a coarse pricing region using the first digit of the
/// ZIP (the USPS national area). Cost multipliers are rough cost-of-living
/// estimates and are combined with the store multiplier.
const List<Region> _regions = [
  Region(id: 'ne', name: 'Northeast', costMultiplier: 1.12), // 0
  Region(id: 'ny', name: 'NY / Mid-Atlantic', costMultiplier: 1.10), // 1
  Region(id: 'matl', name: 'Mid-Atlantic', costMultiplier: 1.04), // 2
  Region(id: 'se', name: 'Southeast', costMultiplier: 0.95), // 3
  Region(id: 'mw', name: 'Midwest', costMultiplier: 0.94), // 4
  Region(id: 'umw', name: 'Upper Midwest', costMultiplier: 0.96), // 5
  Region(id: 'cen', name: 'Central', costMultiplier: 0.93), // 6
  Region(id: 'sc', name: 'South Central', costMultiplier: 0.92), // 7
  Region(id: 'mtn', name: 'Mountain West', costMultiplier: 1.02), // 8
  Region(id: 'west', name: 'West Coast', costMultiplier: 1.14), // 9
];

const Region _unknownRegion =
    Region(id: 'us', name: 'National average', costMultiplier: 1.0);

/// Returns the pricing region for a ZIP code, or the national average if the ZIP
/// is missing or malformed.
Region regionForZip(String zip) {
  final trimmed = zip.trim();
  if (trimmed.isEmpty) return _unknownRegion;
  final first = int.tryParse(trimmed.substring(0, 1));
  if (first == null) return _unknownRegion;
  return _regions[first];
}

/// Basic validity check for a US 5-digit ZIP.
bool isValidZip(String zip) {
  final t = zip.trim();
  return RegExp(r'^\d{5}$').hasMatch(t);
}
