import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cafe.dart';

class PlacesService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Cafe>> getNearbyCafes(double lat, double lon, {double radius = 1000}) async {
    // This query asks Overpass API to find all nodes tagged with amenity=cafe within `radius` meters of lat/lon
    final query = '''
      [out:json];
      node(around:$radius,$lat,$lon)["amenity"="cafe"];
      out body;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        
        return elements.map((json) => Cafe.fromJson(json)).toList();
      } else {
        print('Error fetching cafes: \${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching cafes: \$e');
      return [];
    }
  }
}
