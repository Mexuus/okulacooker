/// Maps a ZIP code to its US state / territory using USPS 3-digit prefix ranges.
/// Fully offline. Military (AA/AE/AP) prefixes return null.
const List<(int, int, String)> _zip3Ranges = [
  (5, 5, 'NY'),
  (6, 7, 'PR'),
  (8, 8, 'VI'),
  (9, 9, 'PR'),
  (10, 27, 'MA'),
  (28, 29, 'RI'),
  (30, 38, 'NH'),
  (39, 49, 'ME'),
  (50, 54, 'VT'),
  (55, 55, 'MA'),
  (56, 59, 'VT'),
  (60, 69, 'CT'),
  (70, 89, 'NJ'),
  (100, 149, 'NY'),
  (150, 196, 'PA'),
  (197, 199, 'DE'),
  (200, 200, 'DC'),
  (201, 201, 'VA'),
  (202, 205, 'DC'),
  (206, 219, 'MD'),
  (220, 246, 'VA'),
  (247, 268, 'WV'),
  (270, 289, 'NC'),
  (290, 299, 'SC'),
  (300, 319, 'GA'),
  (320, 339, 'FL'),
  (341, 349, 'FL'),
  (350, 369, 'AL'),
  (370, 385, 'TN'),
  (386, 397, 'MS'),
  (398, 399, 'GA'),
  (400, 427, 'KY'),
  (430, 459, 'OH'),
  (460, 479, 'IN'),
  (480, 499, 'MI'),
  (500, 528, 'IA'),
  (530, 549, 'WI'),
  (550, 567, 'MN'),
  (569, 569, 'DC'),
  (570, 577, 'SD'),
  (580, 588, 'ND'),
  (590, 599, 'MT'),
  (600, 629, 'IL'),
  (630, 658, 'MO'),
  (660, 679, 'KS'),
  (680, 693, 'NE'),
  (700, 714, 'LA'),
  (716, 729, 'AR'),
  (730, 732, 'OK'),
  (733, 733, 'TX'),
  (734, 749, 'OK'),
  (750, 799, 'TX'),
  (800, 816, 'CO'),
  (820, 831, 'WY'),
  (832, 838, 'ID'),
  (840, 847, 'UT'),
  (850, 865, 'AZ'),
  (870, 884, 'NM'),
  (885, 885, 'TX'),
  (889, 898, 'NV'),
  (900, 961, 'CA'),
  (967, 968, 'HI'),
  (969, 969, 'GU'),
  (970, 979, 'OR'),
  (980, 994, 'WA'),
  (995, 999, 'AK'),
];

const Map<String, String> kStateNames = {
  'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
  'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
  'DC': 'District of Columbia', 'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii',
  'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
  'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
  'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
  'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
  'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico', 'NY': 'New York',
  'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio', 'OK': 'Oklahoma',
  'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
  'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
  'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
  'WI': 'Wisconsin', 'WY': 'Wyoming', 'PR': 'Puerto Rico', 'VI': 'U.S. Virgin Islands',
  'GU': 'Guam',
};

/// Two-letter state code for a 5-digit ZIP, or null if unknown / military.
String? stateForZip(String zip) {
  final t = zip.trim();
  if (t.length < 3) return null;
  final p = int.tryParse(t.substring(0, 3));
  if (p == null) return null;
  for (final (lo, hi, st) in _zip3Ranges) {
    if (p >= lo && p <= hi) return st;
  }
  return null;
}
