import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily meal reminder slots. The id is what the OS keys against, so it
/// must be stable so we can cancel/reschedule.
enum MealReminderSlot {
  breakfast(100, 'Breakfast', "Don't forget to log your breakfast"),
  lunch(101, 'Lunch', "Time to capture your lunch thali"),
  dinner(102, 'Dinner', "Snap your dinner before you tuck in");

  const MealReminderSlot(this.id, this.title, this.body);

  final int id;
  final String title;
  final String body;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Default to device local — timezone package picks this from
    // `DateTime.now().timeZoneName` indirectly; for India keep IST as a
    // fallback so scheduled times line up with what the user picked.
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        // tz already defaults to UTC; that's the worst case.
      }
    }

    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: init);
    _initialized = true;
  }

  /// Asks the OS for permission to show notifications. Returns true if the
  /// user granted at least the alert permission.
  Future<bool> requestPermissions() async {
    await initialize();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return ok ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      return ok ?? true;
    }
    return true;
  }

  Future<void> cancelAll() async {
    await initialize();
    for (final slot in MealReminderSlot.values) {
      await _plugin.cancel(id: slot.id);
    }
  }

  Future<void> cancel(MealReminderSlot slot) async {
    await initialize();
    await _plugin.cancel(id: slot.id);
  }

  /// Schedules [slot] to fire daily at [hour]:[minute] local time.
  Future<void> scheduleDaily({
    required MealReminderSlot slot,
    required int hour,
    required int minute,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: slot.id,
      title: slot.title,
      body: slot.body,
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminders',
          'Meal Reminders',
          channelDescription: 'Daily reminders to log your meals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (kDebugMode) {
      debugPrint(
        '[NotificationService] Next $hour:$minute fires at $scheduled',
      );
    }
    return scheduled;
  }
}
