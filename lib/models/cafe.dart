enum PlaceType { cafe, restaurant }

class Cafe {
  final String id;
  final String name;
  final double lat;
  final double lon;
  double distance;
  final PlaceType type;

  Cafe({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.distance = double.infinity,
    this.type = PlaceType.cafe,
  });

  factory Cafe.fromJson(
    Map<String, dynamic> json, {
    PlaceType type = PlaceType.cafe,
  }) {
    final center = json['center'] as Map<String, dynamic>?;
    final lat = (json['lat'] ?? center?['lat'])?.toDouble() ?? 0.0;
    final lon = (json['lon'] ?? center?['lon'])?.toDouble() ?? 0.0;

    final tags = json['tags'] as Map<String, dynamic>?;
    final defaultName =
        type == PlaceType.restaurant ? 'Unnamed Restaurant' : 'Unnamed Cafe';
    final name = tags?['name'] as String? ??
        tags?['name:en'] as String? ??
        tags?['name:ar'] as String? ??
        defaultName;

    return Cafe(
      id: '${type.name}_${json['id']}',
      name: name,
      lat: lat,
      lon: lon,
      type: type,
    );
  }
}
