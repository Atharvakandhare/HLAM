import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
// import 'screens/dashboard_screen.dart'; // Replaced by MainNavigationScreen
import 'screens/employee_list_screen.dart';
import 'screens/add_employee_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/register_company_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/company_registrations_screen.dart';
import 'services/location_service.dart';
import 'services/reminder_alarm_service.dart';

/// Checks the Play Store for a new version and triggers a flexible in-app update.
/// Silently skips if running outside of a Play Store environment (debug/emulator).
Future<void> _checkForUpdate() async {
  if (kIsWeb) {
    debugPrint('Skipping in-app update check on Web.');
    return;
  }
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      // Flexible update: downloads in background; user can continue using the app
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
    }
  } on PlatformException catch (e) {
    // Not running via Play Store (debug / emulator) — skip silently
    debugPrint('In-app update not available: ${e.message}');
  } catch (e) {
    debugPrint('In-app update check failed: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("FCM background message received: ${message.messageId}");
}

Future<void> _initFcm() async {
  if (kIsWeb) return;

  try {
    final messaging = FirebaseMessaging.instance;
    
    // Request notification permissions
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted push notification permission: ${settings.authorizationStatus}');

    // Set foreground notification options for iOS
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM message received in foreground: ${message.messageId}');
      if (message.notification != null) {
        final title = message.notification?.title ?? 'Attendance Reminder';
        final body = message.notification?.body ?? 'Please check-in or check-out.';
        ReminderAlarmService.triggerImmediateAlarm(title, body);
      }
    });

    // Background/terminated click listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification clicked and opened the app: ${message.messageId}');
    });
  } catch (e) {
    debugPrint('Error initializing FCM messaging: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initFcm();
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }

  _checkForUpdate(); // fire-and-forget; don't await so startup isn't blocked
  await LocationTrackingService.initializeService();
  await ReminderAlarmService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'HLAM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB), // Sleek Royal Blue
            primary: const Color(0xFF2563EB),
            secondary: const Color(0xFF4F46E5), // Indigo Accent
            tertiary: const Color(0xFF0F172A), // Deep Charcoal Slate
            surface: Colors.white,
            onSurface: const Color(0xFF0F172A),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Premium light slate background
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFFF8FAFC),
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFF2563EB), // Royal Blue
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            labelStyle: const TextStyle(
              color: Color(0xFF475569),
            ),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/dashboard': (context) => const MainNavigationScreen(),
          '/add_employee': (context) => const AddEmployeeScreen(),
          '/employees': (context) => const EmployeeListScreen(),
          '/register_company': (context) => const RegisterCompanyScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/company_registrations': (context) => const CompanyRegistrationsScreen(),
        },
      ),
    );
  }
}
