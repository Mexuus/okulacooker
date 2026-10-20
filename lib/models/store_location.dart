/// A specific physical store the user picked (not just the chain), so prices
/// can reflect that store's region and metro area.
class StoreLocationRef {
  final String storeId;
  final String label;
  final String? address;
  final double lat;
  final double lng;
  final String? state;

  const StoreLocationRef({
    required this.storeId,
    required this.label,
    required this.lat,
    required this.lng,
    this.address,
    this.state,
  });

  Map<String, dynamic> toJson() => {
        'storeId': storeId,
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
        'state': state,
      };

  factory StoreLocationRef.fromJson(Map<String, dynamic> j) => StoreLocationRef(
        storeId: j['storeId'] as String,
        label: j['label'] as String,
        address: j['address'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        state: j['state'] as String?,
      );
}
