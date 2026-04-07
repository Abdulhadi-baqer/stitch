import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cafe.dart';

class PlacesService {
  static const List<String> _overpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  Future<List<Cafe>> getNearbyCafes(
    double lat,
    double lon, {
    double radius = 1000,
  }) async {
    final query = '''
      [out:json][timeout:25];
      (
        nwr(around:$radius,$lat,$lon)["amenity"="cafe"];
        nwr(around:$radius,$lat,$lon)["amenity"="coffee_shop"];
        nwr(around:$radius,$lat,$lon)["amenity"="bistro"];
        nwr(around:$radius,$lat,$lon)["shop"="coffee"];
        nwr(around:$radius,$lat,$lon)["name"~"cafe|coffee|kafe|brew|espresso|latte|كافيه|كافيهـ|قهوة|كوفي",i];
      );
      out center;
    ''';
    return _queryOverpass(query, PlaceType.cafe);
  }

  Future<List<Cafe>> getNearbyRestaurants(
    double lat,
    double lon, {
    double radius = 1000,
  }) async {
    final query = '''
      [out:json][timeout:25];
      (
        nwr(around:$radius,$lat,$lon)["amenity"="restaurant"];
        nwr(around:$radius,$lat,$lon)["amenity"="fast_food"];
        nwr(around:$radius,$lat,$lon)["amenity"="food_court"];
      );
      out center;
    ''';
    return _queryOverpass(query, PlaceType.restaurant);
  }

  Future<List<Cafe>> _queryOverpass(String query, PlaceType type) async {
    debugPrint('[PlacesService] ▶ Querying ${type.name}s');

    for (int i = 0; i < _overpassMirrors.length; i++) {
      final url = _overpassMirrors[i];
      debugPrint(
        '[PlacesService] Trying mirror ${i + 1}/${_overpassMirrors.length}: $url',
      );

      try {
        final response = await http
            .post(Uri.parse(url), body: {'data': query})
            .timeout(const Duration(seconds: 30));

        debugPrint(
          '[PlacesService] ◀ HTTP ${response.statusCode} from mirror ${i + 1}',
        );

        if (response.statusCode == 200) {
          try {
            final data = json.decode(response.body);
            final List<dynamic> elements = data['elements'] ?? [];
            debugPrint('[PlacesService] ✅ Parsed ${elements.length} results');
            return elements
                .map((json) => Cafe.fromJson(json, type: type))
                .toList();
          } catch (e) {
            debugPrint('[PlacesService] ❌ JSON parse failed: $e');
            continue;
          }
        } else if (response.statusCode == 504 || response.statusCode == 429) {
          debugPrint(
            '[PlacesService] ⚠️ ${response.statusCode} from mirror ${i + 1}, trying next...',
          );
          continue;
        } else {
          debugPrint(
            '[PlacesService] ❌ Unexpected status ${response.statusCode}',
          );
          return [];
        }
      } catch (e) {
        debugPrint('[PlacesService] ❌ Mirror ${i + 1} failed: $e');
        continue;
      }
    }

    debugPrint('[PlacesService] ❌ All mirrors failed, returning empty list');
    return [];
  }
}
