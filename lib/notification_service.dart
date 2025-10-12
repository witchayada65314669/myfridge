import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// ✅ เริ่มต้นระบบแจ้งเตือน (ทั้ง Local + Firebase)
  static Future<void> init() async {
    // โหลด timezone ก่อนใช้
    tzData.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("🟢 Notification tapped: ${response.payload}");
      },
    );

    // ✅ ฟังข้อความจาก FCM ตอนแอปเปิดอยู่ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          title: notification.title ?? "📢 แจ้งเตือนใหม่",
          body: notification.body ?? "มีข้อความใหม่เข้ามา!",
        );
      }
    });

    debugPrint("✅ NotificationService initialized successfully");
  }

  /// ✅ แสดงแจ้งเตือนทันที (ใช้ในแอป)
  static Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'instant_channel',
      'Instant Notifications',
      channelDescription: 'แสดงการแจ้งเตือนทันทีภายในแอป',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
    );

    debugPrint("📩 Instant notification shown: $title");
  }

  /// ✅ แจ้งเตือนทั่วไป (ใช้ตอนรับจาก Firebase)
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      'Firebase Notifications',
      channelDescription: 'ช่องแจ้งเตือนจาก Firebase',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );

    debugPrint("📨 Firebase notification displayed: $title");
  }

  /// ✅ แจ้งเตือนรายวัน (ตั้งเวลา เช่น 9 โมงเช้า)
  static Future<void> scheduleDailyNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Daily Notifications',
      channelDescription: 'แจ้งเตือนสรุปรายวันจากตู้เย็น',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);

    // ถ้าเลยเวลาแล้วให้ข้ามไปวันถัดไป
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      title,
      body,
      scheduledTime,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("🕘 Daily notification scheduled for 9:00 AM local time");
  }

  /// ✅ ยกเลิกการแจ้งเตือนทั้งหมด
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint("🧹 All scheduled notifications cancelled.");
  }

  /// ✅ ทดสอบแจ้งเตือนด้วยปุ่ม (ใช้ในหน้า HomePage)
  static Future<void> testNotification() async {
    await showInstantNotification("🚀 ทดสอบแจ้งเตือน", "ข้อความทดสอบจาก NotificationService!");
  }
}
