import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // DateTime.weekday: Mon=1 ... Sun=7
  static const Map<int, String> _messages = {
    DateTime.sunday:
        '🌅 A new story from Shankara awaits you this morning.',
    DateTime.monday:
        '🪔 Begin the week with a quiet teaching from Shankara.',
    DateTime.tuesday:
        '🌿 Today\'s gentle reflection awaits you in MyShankara.',
    DateTime.wednesday:
        '🌼 Pause for a moment. Shankara has something new to share.',
    DateTime.thursday:
        '🌺 Shankara awaits to share today\'s wisdom.',
    DateTime.friday:
        '🌙 Spend a calm moment with Shankara today.',
    DateTime.saturday:
        '🌞 Slow down. A peaceful Darshan awaits you today.',
  };

  static const String _channelId = 'daily_notifications';
  static const String _channelName = 'Daily Notifications';
  static const String _channelDesc = 'Daily reflections from MyShankara';

  bool _initialized = false;
  bool _exactAlarmPermissionRequested = false;

  /// Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    final deviceTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTz.identifier));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Explicitly create the channel so importance/sound survive app updates.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// Request OS notification permission. Returns true if granted.
  Future<bool> requestPermissions() async {
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await androidImpl?.requestNotificationsPermission() ?? true;

    return iosGranted && androidGranted;
  }

  /// Requests exact-alarm permission once per session, then returns the best
  /// available schedule mode. Falls back to inexact if exact is denied.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    if (!_exactAlarmPermissionRequested) {
      await androidImpl.requestExactAlarmsPermission();
      _exactAlarmPermissionRequested = true;
    }

    final canExact =
        await androidImpl.canScheduleExactNotifications() ?? false;
    debugPrint('[Notifications] canScheduleExactNotifications=$canExact');

    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    debugPrint('[Notifications] scheduleMode=$mode');
    return mode;
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }

  /// Cancel everything, then schedule one repeating weekly notification per
  /// weekday at [hour]:[minute]. Notification id = weekday number (1–7).
  Future<void> scheduleWeekly({
    required int hour,
    required int minute,
  }) async {
    await cancelAll();
    final mode = await _resolveScheduleMode();

    for (final entry in _messages.entries) {
      final weekday = entry.key;
      final message = entry.value;
      final scheduled = _nextInstanceOf(weekday, hour, minute);
      await _plugin.zonedSchedule(
        weekday,
        'MyShankara',
        message,
        scheduled,
        _details(),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
    debugPrint('[Notifications] scheduleWeekly done — mode=$mode');
  }

  /// One-off test notification (id 999) fired after [seconds] seconds.
  /// No matchDateTimeComponents — fires exactly once, not weekly.
  Future<void> scheduleTestInSeconds(int seconds) async {
    final mode = await _resolveScheduleMode();
    debugPrint('[Notifications] scheduleTestInSeconds($seconds) mode=$mode');

    await _plugin.zonedSchedule(
      999,
      'MyShankara Test',
      'Test notification — delivery confirmed.',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      _details(),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async => _plugin.cancelAll();

  // Next occurrence of [weekday] at [hour]:[minute] in local timezone.
  tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
