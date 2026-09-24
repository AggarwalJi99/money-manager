import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: settings,
    );
  }

  static Future<void> requestPermission() async {
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
  }

  static Future<void> syncBillReminders({
    required List<Map<String, dynamic>> bills,
  }) async {
    await _plugin.cancelAll();

    for (var i = 0; i < bills.length; i++) {
      final bill = bills[i];

      if (bill['isPaid'] == true) continue;

      final dueDate = bill['dueDate'] as DateTime;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day,
        9,
      );

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }

      const androidDetails = AndroidNotificationDetails(
        'bill_reminders',
        'Bill Reminders',
        channelDescription: 'Reminders for upcoming bills',
        importance: Importance.high,
        priority: Priority.high,
      );

      const details = NotificationDetails(
        android: androidDetails,
      );

      await _plugin.zonedSchedule(
        id: 1000 + i,
        title: 'Bill Due Today',
        body: '${bill['name']} - ₹${bill['amount']}',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelBillReminders() async {
    await _plugin.cancelAll();
  }
}
