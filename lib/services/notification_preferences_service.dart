import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesService {
  static const _cafesKey = 'notif_cafes_enabled';
  static const _restaurantsKey = 'notif_restaurants_enabled';

  Future<bool> getCafesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cafesKey) ?? true;
  }

  Future<void> setCafesEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cafesKey, value);
  }

  Future<bool> getRestaurantsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_restaurantsKey) ?? true;
  }

  Future<void> setRestaurantsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_restaurantsKey, value);
  }
}
