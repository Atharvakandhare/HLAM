# iOS Notifications Fix Documentation

This document outlines the exact changes made across the Flutter application and native iOS codebase to resolve the issue where the iOS Notification permission dialog failed to appear.

## The Root Cause
The `GoogleService-Info.plist` file is currently missing from the iOS project. Because of this, `Firebase.initializeApp()` was throwing a silent exception on iOS. Previously, the local notifications initialization (`ReminderAlarmService.init()`) was nested inside the Firebase initialization flow (`_initFcm()`). As a result, when Firebase crashed, the entire notification setup was skipped, and the OS was never instructed to ask the user for permission.

Additionally, `flutter_local_notifications` was missing its specific iOS configuration (`DarwinInitializationSettings`) and native iOS delegate mappings.

---

## Code Changes in Detail

### 1. `lib/services/reminder_alarm_service.dart`
**Goal:** Explicitly tell iOS to request notification permissions (Alerts, Badges, and Sounds) during the local notifications setup.

**Changes Made:**
We imported `DarwinInitializationSettings` and added it to the general `InitializationSettings`.

```diff
     // 2. Setup notification settings
     const AndroidInitializationSettings androidInit =
         AndroidInitializationSettings('@drawable/ic_bg_service_small');
 
+    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
+      requestAlertPermission: true,
+      requestBadgePermission: true,
+      requestSoundPermission: true,
+    );
+
     const InitializationSettings initSettings = InitializationSettings(
       android: androidInit,
+      iOS: iosInit,
     );
```

---

### 2. `lib/main.dart`
**Goal:** Decouple local notifications from Firebase so that the iOS permission prompt triggers reliably even if Firebase crashes or lacks the `GoogleService-Info.plist`.

**Changes Made:**
We removed `await ReminderAlarmService.init()` from inside `_initFcm()` and moved it directly into the `main()` function right before `runApp()`.

**Removed from `_initFcm()`:**
```diff
     // Request notification permissions
     final settings = await messaging.requestPermission(
       alert: true,
       badge: true,
       sound: true,
     );
     debugPrint('User granted push notification permission: ${settings.authorizationStatus}');
 
-    // Initialize local notifications service so we can display foreground alerts with sound
-    await ReminderAlarmService.init();
```

**Added to `main()`:**
```diff
   _checkForUpdate(); // fire-and-forget; don't await so startup isn't blocked
   await LocationTrackingService.initializeService();
+  await ReminderAlarmService.init();
   runApp(const MyApp());
 }
```

---

### 3. `ios/Runner/AppDelegate.swift`
**Goal:** Ensure the iOS operating system can properly route foreground notifications and handle permissions for `flutter_local_notifications`.

**Changes Made:**
We registered the app as a `UNUserNotificationCenterDelegate` just before the Flutter plugins are registered.

```diff
       }
     })
 
+    if #available(iOS 10.0, *) {
+      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
+    }
+
     GeneratedPluginRegistrant.register(with: self)
     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
   }
```

## Next Steps for Full Firebase Push Support
While local alarms and simulator payload testing (`.apns`) will now work flawlessly, real **Firebase Cloud Messaging (FCM)** push notifications to physical iOS devices still require:
1. Adding the **Push Notifications** and **Background Modes (Remote Notifications)** capabilities in Xcode.
2. Generating a `GoogleService-Info.plist` from your Firebase console and adding it to `ios/Runner`.
3. Generating an APNs `.p8` Auth Key from your Apple Developer account and uploading it to Firebase.
