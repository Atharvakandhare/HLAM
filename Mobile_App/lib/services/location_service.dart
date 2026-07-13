import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'reminder_alarm_service.dart';

@pragma('vm:entry-point')
class LocationTrackingService {
  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    if (kIsWeb) {
      debugPrint("Skipping Background Location Service Initialization on Web.");
      return;
    }
    
    // Ensure notifications and channels are initialized
    try {
      await ReminderAlarmService.init();
    } catch (e) {
      debugPrint("LocationTrackingService: Failed to init ReminderAlarmService: $e");
    }

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Started only on check-in
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'marketing_tracking_channel',
        initialNotificationTitle: 'Marketing Location Tracking',
        initialNotificationContent: 'Tracking active field movements...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Enable platform channels in background isolate
    DartPluginRegistrant.ensureInitialized();

    debugPrint("Background Location Tracking Service Started.");

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'Marketing Location Tracking',
        content: 'Tracking active field movements...',
      );
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 1. Log immediately upon starting to register the exact Check-in point
    await _performLocationLog(service);

    // 2. Execute periodic logging every 15 minutes
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      await _performLocationLog(service);
    });
  }

  static Future<String> _getCleanEnglishAddress(double lat, double long, String rawAddress) async {
    // If rawAddress is purely ASCII, it's already safe.
    if (!RegExp(r'[^\x00-\x7F]').hasMatch(rawAddress)) {
      return rawAddress.length > 255 ? rawAddress.substring(0, 255) : rawAddress;
    }

    // Attempt web-based translation via OpenStreetMap Nominatim
    String? webAddress;
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$long&accept-language=en'
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'AttendanceManagementApp/1.0',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        webAddress = data['display_name'];
      }
    } catch (e) {
      debugPrint("OSM geocoding translation fallback failed: $e");
    }

    // Use web address if valid and purely ASCII
    if (webAddress != null && webAddress.isNotEmpty && !RegExp(r'[^\x00-\x7F]').hasMatch(webAddress)) {
      return webAddress.length > 255 ? webAddress.substring(0, 255) : webAddress;
    }

    // If web geocoder failed or still returned non-ASCII, sanitize the address
    final String addressToSanitize = webAddress ?? rawAddress;
    String sanitized = addressToSanitize.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    
    // Clean up multiple spaces, consecutive commas, leading/trailing commas
    sanitized = sanitized
        .replaceAll(RegExp(r',\s*,'), ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.startsWith(',')) sanitized = sanitized.substring(1).trim();
    if (sanitized.endsWith(',')) sanitized = sanitized.substring(0, sanitized.length - 1).trim();

    // If the sanitized string contains no letters or numbers, use coordinates
    if (sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').isEmpty) {
      return "${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}";
    }

    return sanitized.length > 255 ? sanitized.substring(0, 255) : sanitized;
  }

  static Future<void> _performLocationLog(ServiceInstance service) async {
    try {
      // 1. Double check authorization token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        debugPrint("[Background Location] No authentication token found. Halting logging step.");
        return;
      }

      // 2. Fetch current high accuracy location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("[Background Location] GPS is disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint("[Background Location] Geolocation permission is denied.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 3. Reverse Geocode Coordinates to Address
      String address = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
      try {
        await setLocaleIdentifier("en_US");
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 10));
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String rawAddress = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
          address = await _getCleanEnglishAddress(position.latitude, position.longitude, rawAddress);
        }
      } catch (geocodingError) {
        debugPrint("[Background Location] Geocoding failed: $geocodingError");
      }

      // 4. Post to Backend Location Logs Endpoint
      final url = Uri.parse('${ApiService.baseUrl}/location/log');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address,
        }),
      );

      if (response.statusCode == 201) {
        debugPrint("[Background Location] Coordinates logged: (${position.latitude}, ${position.longitude}) @ $address");
      } else if (response.statusCode == 401) {
        debugPrint("[Background Location] Unauthorized (401)! Stopping background service.");
        service.stopSelf();
      } else {
        debugPrint("[Background Location] Log failed with status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[Background Location] Exception during log cycle: $e");
    }
  }

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }
}
