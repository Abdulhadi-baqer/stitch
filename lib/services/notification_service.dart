import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationChannel { cafe, restaurant }

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.cafe,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails;
    final DarwinNotificationDetails iosDetails;

    switch (channel) {
      case NotificationChannel.cafe:
        androidDetails = const AndroidNotificationDetails(
          'cafe_channel',
          'Cafes',
          channelDescription: 'Notifications for nearby cafes and coffee shops',
          importance: Importance.max,
          priority: Priority.high,
        );
        iosDetails = const DarwinNotificationDetails(
          threadIdentifier: 'cafe_channel',
        );
      case NotificationChannel.restaurant:
        androidDetails = const AndroidNotificationDetails(
          'restaurant_channel',
          'Restaurants',
          channelDescription: 'Notifications for nearby restaurants',
          importance: Importance.max,
          priority: Priority.high,
        );
        iosDetails = const DarwinNotificationDetails(
          threadIdentifier: 'restaurant_channel',
        );
    }

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
