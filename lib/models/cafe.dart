class Cafe {
  final String id;
  final String name;
  final double lat;
  final double lon;
  double distance;

  Cafe({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.distance = double.infinity,
  });

  factory Cafe.fromJson(Map<String, dynamic> json) {
    return Cafe(
      id: json['id'].toString(),
      name: json['tags'] != null && json['tags']['name'] != null 
          ? json['tags']['name'] 
          : 'Unnamed Cafe',
      lat: json['lat']?.toDouble() ?? 0.0,
      lon: json['lon']?.toDouble() ?? 0.0,
    );
  }
}
