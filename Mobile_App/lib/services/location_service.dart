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

class LocationTrackingService {
  static Future<void> initializeService() async {
    if (kIsWeb) {
      debugPrint("Skipping Background Location Service Initialization on Web.");
      return;
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
      String address = "Unknown Location";
      try {
        await setLocaleIdentifier("en_US");
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String rawAddress = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
          address = rawAddress.length > 255 ? rawAddress.substring(0, 255) : rawAddress;
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
