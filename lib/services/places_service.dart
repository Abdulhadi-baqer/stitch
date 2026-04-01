import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cafe.dart';

class PlacesService {
  // Multiple mirrors — if one returns 504, we try the next
  static const List<String> _overpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  Future<List<Cafe>> getNearbyCafes(
    double lat,
    double lon, {
    double radius = 3000,
  }) async {
    // [timeout:10] tells the Overpass server to give up after 10s
    // instead of hanging and eventually returning a 504
    // Union query: catches amenity=cafe, amenity=coffee_shop,
    // and any place whose name contains "cafe" or "coffee"
    // (common in Kuwait where OSM tagging is inconsistent)
    final query =
        '''
      [out:json][timeout:20];
      (
        node(around:$radius,$lat,$lon)["amenity"="cafe"];
        node(around:$radius,$lat,$lon)["amenity"="coffee_shop"];
        node(around:$radius,$lat,$lon)["name"~"cafe|coffee|كافيه|قهوة",i];
      );
      out body;
    ''';

    debugPrint('[PlacesService] ▶ Querying ($lat, $lon) radius=${radius}m');

    for (int i = 0; i < _overpassMirrors.length; i++) {
      final url = _overpassMirrors[i];
      debugPrint(
        '[PlacesService] Trying mirror ${i + 1}/${_overpassMirrors.length}: $url',
      );

      try {
        final response = await http
            .post(Uri.parse(url), body: {'data': query})
            .timeout(const Duration(seconds: 15)); // client-side hard timeout

        debugPrint(
          '[PlacesService] ◀ HTTP ${response.statusCode} from mirror ${i + 1}',
        );

        if (response.statusCode == 200) {
          try {
            final data = json.decode(response.body);
            final List<dynamic> elements = data['elements'] ?? [];
            debugPrint('[PlacesService] ✅ Parsed ${elements.length} results');
            return elements.map((json) => Cafe.fromJson(json)).toList();
          } catch (e) {
            debugPrint(
              '[PlacesService] ❌ JSON parse failed (HTML timeout page?): $e',
            );
            // Try next mirror
            continue;
          }
        } else if (response.statusCode == 504 || response.statusCode == 429) {
          debugPrint(
            '[PlacesService] ⚠️ ${response.statusCode} from mirror ${i + 1}, trying next...',
          );
          continue; // Try next mirror
        } else {
          debugPrint(
            '[PlacesService] ❌ Unexpected status ${response.statusCode}',
          );
          return [];
        }
      } catch (e) {
        debugPrint('[PlacesService] ❌ Mirror ${i + 1} failed: $e');
        continue; // Try next mirror
      }
    }

    debugPrint('[PlacesService] ❌ All mirrors failed, returning empty list');
    return [];
  }
}
