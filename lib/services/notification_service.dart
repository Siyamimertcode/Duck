import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyNotificationHourMorning = 'notif_hour_morning';
  static const String _keyNotificationHourEvening = 'notif_hour_evening';

  // Notification IDs
  static const int _morningNotifId = 1001;
  static const int _eveningNotifId = 1002;

  // Motivational messages — personalized with user name
  static const List<String> _morningMessages = [
    '{name}, günaydın! ☀️ Bugün İngilizce öğrenmeye devam etmek ister misin?',
    '{name}, yeni bir gün yeni fırsatlar demek! 🦆 Hadi bir ders tamamlayalım!',
    '{name}, sabah erken kalkanlar daha hızlı öğrenir! 📚 Hazır mısın?',
    '{name}, bugün sadece 5 dakikanı ayır ve farkı gör! 🚀',
    'Günaydın {name}! 🌅 Bugünkü dersini tamamlamayı unutma!',
    '{name}, her gün bir adım daha! 👣 İngilizce seni bekliyor.',
    'Hey {name}! 🎯 Bugünkü hedefini belirledin mi? Hadi başlayalım!',
    '{name}, kahveni al ve dersine başla! ☕ Bugün harika bir gün!',
  ];

  static const List<String> _eveningMessages = [
    '{name}, güzel ilerliyordun bence bırakma! 💪',
    '{name}, bugün dersini tamamladın mı? Hâlâ vakit var! 🌙',
    '{name}, yatmadan önce hızlı bir ders ne dersin? 😊',
    '{name}, düzenli çalışan kazanır! 🏆 Bugünkü dersini yaptın mı?',
    '{name}, İngilizce serisini bozmayalım! 🔥 Hadi bir ders daha!',
    '{name}, az kaldı! Bugünkü hedefine ulaşmak için bir ders daha yap! ⭐',
    'Bugün çalıştın mı {name}? 📖 Gece olmadan bir ders tamamla!',
    '{name}, uyumadan önce beynini çalıştır! 🧠 Hızlı bir egzersiz yap!',
  ];

  static const List<String> _comeBackMessages = [
    '{name}, seni özledik! 🦆 Geri dönüp devam etmek ister misin?',
    '{name}, İngilizce yolculuğun seni bekliyor! 🚀 Hadi devam edelim!',
    '{name}, bir süredir görüşmedik! 😢 Duck seni çok özledi!',
    '{name}, birkaç dakika ayırsan bile büyük fark yaratır! 💡',
  ];

  /// Initialize the notification plugin
  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    } catch (e) {
      debugPrint('Notification initialize error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Check if notifications are enabled
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  /// Enable or disable notifications
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);

    if (enabled) {
      await scheduleDaily();
    } else {
      await cancelAll();
    }
  }

  /// Schedule daily morning and evening notifications
  Future<void> scheduleDaily() async {
    try {
      final enabled = await isEnabled();
      if (!enabled) return;

      final userName = await UserPreferences.getUserName() ?? 'Arkadaş';

      // Cancel old ones first
      await cancelAll();

      // Schedule morning notification (09:00)
      await _scheduleDailyNotification(
        id: _morningNotifId,
        hour: 9,
        minute: 0,
        title: 'Duck 🦆',
        body: _getRandomMessage(_morningMessages, userName),
      );

      // Schedule evening notification (20:00)
      await _scheduleDailyNotification(
        id: _eveningNotifId,
        hour: 20,
        minute: 0,
        title: 'Duck 🦆',
        body: _getRandomMessage(_eveningMessages, userName),
      );

      debugPrint('🔔 Daily notifications scheduled (09:00 & 20:00)');
    } catch (e) {
      debugPrint('Notification scheduleDaily error: $e');
    }
  }

  /// Schedule a single daily notification
  Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'duck_daily_reminders',
      'Günlük Hatırlatmalar',
      channelDescription: 'İngilizce öğrenme hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1D6755),
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Get the next instance of a specific time today or tomorrow
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Get a random personalized message
  String _getRandomMessage(List<String> messages, String userName) {
    final random = Random();
    final msg = messages[random.nextInt(messages.length)];
    return msg.replaceAll('{name}', userName);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Show an immediate test notification
  Future<void> showTestNotification() async {
    final userName = await UserPreferences.getUserName() ?? 'Arkadaş';
    final allMessages = [
      ..._morningMessages,
      ..._eveningMessages,
      ..._comeBackMessages,
    ];
    final body = _getRandomMessage(allMessages, userName);

    final androidDetails = AndroidNotificationDetails(
      'duck_daily_reminders',
      'Günlük Hatırlatmalar',
      channelDescription: 'İngilizce öğrenme hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1D6755),
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(0, 'Duck 🦆', body, details);
  }
}
