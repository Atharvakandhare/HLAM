import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/user.dart';

class ReminderAlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'attendance_reminder_channel_v2';
  static const String channelName = 'Attendance Reminders';
  static const String channelDesc =
      'Channel for check-in and check-out reminders with alarm sound.';

  static bool _initialized = false;

  /// Initializes the notification plugin, timezone database, and creates the custom sound channel.
  static Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize timezones
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("ReminderAlarmService: Timezone init failed: $e");
    }

    // 2. Setup notification settings
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Dismiss the active alarms/sound if tapped
        cancelActiveReminders();
      },
    );

    // 3. Register custom sound channel on Android
    final AndroidFlutterLocalNotificationsPlugin? androidPlatform =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      // 1. Create main reminder alarm channel
      await androidPlatform.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(
              'mixkit_digital_clock_digital_alarm_buzzer_992'),
        ),
      );

      // 2. Create background tracking channel (to prevent bad notification config crashes)
      try {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'marketing_tracking_channel',
            'Marketing Location Tracking',
            description: 'Tracking active field movements...',
            importance: Importance.low,
            playSound: false,
          ),
        );
      } catch (e) {
        debugPrint("ReminderAlarmService: Error creating background tracking channel: $e");
      }
      
      // Request notification permission on startup (Android 13+)
      try {
        await androidPlatform.requestNotificationsPermission();
      } catch (e) {
        debugPrint("ReminderAlarmService: Error requesting notification permission: $e");
      }
      
      try {
        final bool? canScheduleExact = await androidPlatform.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          await androidPlatform.requestExactAlarmsPermission();
        }
      } catch (e) {
        debugPrint("ReminderAlarmService: Error checking/requesting exact alarm permission: $e");
      }
    }

    _initialized = true;
    debugPrint("ReminderAlarmService: Initialized successfully");
  }

  /// Calculates and schedules alarm reminders for the next 7 days based on the user's company settings.
  static Future<void> scheduleAlarms(User user, {bool hasCheckedIn = false, bool hasCheckedOut = false}) async {
    await init();

    try {
      final localTime = tz.TZDateTime.now(tz.local);
      debugPrint("ReminderAlarmService: Timezone check - tz.local is ${tz.local.name}. tz.now is $localTime, device.now is ${DateTime.now()}");
    } catch (e) {
      debugPrint("ReminderAlarmService: Timezone check failed: $e");
    }

    final role = user.role.toLowerCase();
    // System admins and company admins do not have check-in rules or alarms.
    if (role == 'system_admin' || role == 'company_admin') {
      debugPrint("ReminderAlarmService: Admins bypass alarm scheduling.");
      await cancelAllAlarms();
      return;
    }

    final TimeOfDay? checkInTime = _parseTime(user.companyCheckInTime);
    final TimeOfDay? checkOutTime = _parseTime(user.companyCheckOutTime);

    if (checkInTime == null || checkOutTime == null) {
      debugPrint("ReminderAlarmService: Company check-in/out times are not set.");
      return;
    }

    // Alarms trigger 1 minute past the actual check-in/check-out time
    final TimeOfDay checkInReminderTime = _addMinutes(checkInTime, 1);
    final TimeOfDay checkOutReminderTime = _addMinutes(checkOutTime, 1);

    final now = DateTime.now();

    // 1. Schedule check-in reminders for the next 7 days (IDs 100 to 106)
    for (int i = 0; i < 7; i++) {
      final scheduledDate = now.add(Duration(days: i));
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        checkInReminderTime.hour,
        checkInReminderTime.minute,
      );

      final int notificationId = 100 + i;

      if (i == 0) {
        // Today
        // Skip/cancel today if user already checked in, or it's already past the alarm time today
        if (hasCheckedIn || now.isAfter(scheduledDateTime)) {
          await _notificationsPlugin.cancel(notificationId);
          continue;
        }
      }

      await _scheduleIndividualAlarm(
        id: notificationId,
        title: 'Check-In Reminder',
        body: 'You have not checked in yet. Please mark your check-in attendance!',
        scheduledDateTime: scheduledDateTime,
      );
    }

    // 2. Schedule check-out reminders for the next 7 days (IDs 200 to 206)
    for (int i = 0; i < 7; i++) {
      final scheduledDate = now.add(Duration(days: i));
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        checkOutReminderTime.hour,
        checkOutReminderTime.minute,
      );

      final int notificationId = 200 + i;

      if (i == 0) {
        // Today
        // Only trigger check-out today if checked in AND not checked out yet, and before trigger time
        if (!hasCheckedIn || hasCheckedOut || now.isAfter(scheduledDateTime)) {
          await _notificationsPlugin.cancel(notificationId);
          continue;
        }
      }

      await _scheduleIndividualAlarm(
        id: notificationId,
        title: 'Check-Out Reminder',
        body: 'You have not checked out yet. Please mark your check-out attendance!',
        scheduledDateTime: scheduledDateTime,
      );
    }
  }

  /// Schedules a single precise timezone-aware alarm.
  static Future<void> _scheduleIndividualAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
  }) async {
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound(
          'mixkit_digital_clock_digital_alarm_buzzer_992'),
      playSound: true,
      additionalFlags: Int32List.fromList(<int>[4]), // Loops audio continuously (FLAG_INSISTENT)
      audioAttributesUsage: AudioAttributesUsage.alarm,
      timeoutAfter: 30000, // Auto dismiss after 30 seconds
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
    );

    final iOSDetails = const DarwinNotificationDetails(
      sound: 'mixkit_digital_clock_digital_alarm_buzzer_992.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    final AndroidFlutterLocalNotificationsPlugin? androidPlatform =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      try {
        final bool? canSchedule = await androidPlatform.canScheduleExactNotifications();
        if (canSchedule == false) {
          scheduleMode = AndroidScheduleMode.inexact;
          debugPrint("ReminderAlarmService: Exact notification permission not granted. Falling back to inexact scheduling.");
        }
      } catch (permissionError) {
        debugPrint("ReminderAlarmService: Error checking exact notification permissions: $permissionError");
        scheduleMode = AndroidScheduleMode.inexact;
      }
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("ReminderAlarmService: Scheduled alarm $id at $tzScheduledTime using mode ${scheduleMode.name}");
    } catch (e) {
      debugPrint("ReminderAlarmService: Error scheduling alarm $id with mode ${scheduleMode.name}: $e");
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        debugPrint("ReminderAlarmService: Retrying scheduling with inexact mode...");
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            tzScheduledTime,
            details,
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint("ReminderAlarmService: Successfully scheduled alarm $id at $tzScheduledTime using inexact mode fallback");
        } catch (retryError) {
          debugPrint("ReminderAlarmService: Critical error during fallback scheduling: $retryError");
        }
      }
    }
  }

  /// Triggers an immediate alarm/notification (for foreground popup sound playback).
  static Future<void> triggerImmediateAlarm(String title, String body) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound(
          'mixkit_digital_clock_digital_alarm_buzzer_992'),
      playSound: true,
      additionalFlags: Int32List.fromList(<int>[4]), // Loops audio continuously (FLAG_INSISTENT)
      audioAttributesUsage: AudioAttributesUsage.alarm,
      timeoutAfter: 30000, // Auto dismiss after 30 seconds
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
    );

    final iOSDetails = const DarwinNotificationDetails(
      sound: 'mixkit_digital_clock_digital_alarm_buzzer_992.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    try {
      await _notificationsPlugin.show(300, title, body, details);
      debugPrint("ReminderAlarmService: Immediate foreground alarm triggered.");
    } catch (e) {
      debugPrint("ReminderAlarmService: Error triggering immediate alarm: $e");
    }
  }

  /// Cancels today's check-in alarm.
  static Future<void> cancelCheckInReminder() async {
    await _notificationsPlugin.cancel(100);
    debugPrint("ReminderAlarmService: Cancelled today's check-in reminder.");
  }

  /// Cancels today's check-out alarm.
  static Future<void> cancelCheckOutReminder() async {
    await _notificationsPlugin.cancel(200);
    debugPrint("ReminderAlarmService: Cancelled today's check-out reminder.");
  }

  /// Cancels any currently ringing/active reminder notification (stops sound immediately).
  static Future<void> cancelActiveReminders() async {
    await _notificationsPlugin.cancel(100);
    await _notificationsPlugin.cancel(200);
    await _notificationsPlugin.cancel(300);
    debugPrint("ReminderAlarmService: Cancelled active reminders.");
  }

  /// Clears all future scheduled reminder alarms (e.g. on logout).
  static Future<void> cancelAllAlarms() async {
    for (int i = 100; i <= 106; i++) {
      await _notificationsPlugin.cancel(i);
    }
    for (int i = 200; i <= 206; i++) {
      await _notificationsPlugin.cancel(i);
    }
    await _notificationsPlugin.cancel(300);
    debugPrint("ReminderAlarmService: Cancelled all scheduled alarms.");
  }

  static TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint("ReminderAlarmService: Parse time error: $e");
    }
    return null;
  }

  static TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    int totalMins = time.hour * 60 + time.minute + minutes;
    int newHour = (totalMins ~/ 60) % 24;
    int newMin = totalMins % 60;
    return TimeOfDay(hour: newHour, minute: newMin);
  }
}
