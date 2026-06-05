import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class ApiException implements Exception {
  final String userMessage;
  final String devDetails;
  final String? url;
  final int? statusCode;

  ApiException({
    required this.userMessage,
    required this.devDetails,
    this.url,
    this.statusCode,
  });

  @override
  String toString() => userMessage;
}

class ApiService {
  static ApiException? lastApiException;

  // Live API production server
  static const String baseUrl = 'https://intime.hirelyft.in/api';


  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) return token;
    } catch (e) {
      debugPrint('Secure storage read error, falling back to SharedPreferences: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      debugPrint('SharedPreferences read error: $e');
      return null;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _makeRequest(Future<http.Response> Function() requestFn, String endpoint) async {
    final fullUrl = '$baseUrl$endpoint';
    try {
      final response = await requestFn().timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;

      String userMessage = 'Unable to connect to the server.';
      String devDetails = 'Error: $e\nAttempted URL: $fullUrl';

      if (e is TimeoutException) {
        userMessage = 'The request timed out. The server might be busy or slow.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Connection refused') || 
                 e.toString().contains('Failed host lookup')) {
        userMessage = 'Cannot reach the server. Please check your internet connection or verify that the server URL is correct and active.';
      } else if (e.toString().contains('ClientException')) {
        userMessage = 'A connection error occurred. Please check your connection.';
      }

      final apiException = ApiException(
        userMessage: userMessage,
        devDetails: devDetails,
        url: fullUrl,
      );
      lastApiException = apiException;
      throw apiException;
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    return _makeRequest(
      () async => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ),
      endpoint,
    );
  }

  Future<dynamic> get(String endpoint) async {
    return _makeRequest(
      () async => http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      ),
      endpoint,
    );
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    return _makeRequest(
      () async => http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ),
      endpoint,
    );
  }

  Future<dynamic> delete(String endpoint) async {
    return _makeRequest(
      () async => http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      ),
      endpoint,
    );
  }

  dynamic _processResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else if (response.statusCode == 401) {
        // Clear local credentials and redirect to login screen
        deleteToken();
        MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        final apiException = ApiException(
          userMessage: data['message'] ?? 'Unauthorized: Session expired or invalid. Please login again.',
          devDetails: 'Status: 401 Unauthorized\nURL: ${response.request?.url}\nResponse: ${response.body}',
          url: response.request?.url.toString(),
          statusCode: response.statusCode,
        );
        lastApiException = apiException;
        throw apiException;
      } else {
        final apiException = ApiException(
          userMessage: data['message'] ?? 'The server returned an error (Status ${response.statusCode}).',
          devDetails: 'Status: ${response.statusCode}\nURL: ${response.request?.url}\nResponse: ${response.body}',
          url: response.request?.url.toString(),
          statusCode: response.statusCode,
        );
        lastApiException = apiException;
        throw apiException;
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is FormatException) {
        // Handle non-JSON responses (e.g., HTML error pages)
        final apiException = ApiException(
          userMessage: 'The server returned an invalid response format.',
          devDetails: 'Status: ${response.statusCode} - ${response.reasonPhrase}\nURL: ${response.request?.url}\nBody: ${response.body}\nError: $e',
          url: response.request?.url.toString(),
          statusCode: response.statusCode,
        );
        lastApiException = apiException;
        throw apiException;
      }
      final apiException = ApiException(
        userMessage: 'An unexpected error occurred.',
        devDetails: 'Error: $e\nURL: ${response.request?.url}',
        url: response.request?.url.toString(),
        statusCode: response.statusCode,
      );
      lastApiException = apiException;
      throw apiException;
    }
  }

  Future<void> setToken(String token) async {
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (e) {
      debugPrint('Secure storage write error, attempting recovery: $e');
      try {
        await _storage.deleteAll();
        await _storage.write(key: 'jwt_token', value: token);
      } catch (err) {
        debugPrint('Secure storage recovery failed: $err');
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
    } catch (e) {
      debugPrint('SharedPreferences setToken error: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: 'jwt_token');
    } catch (e) {
      debugPrint('Secure storage delete error, attempting recovery: $e');
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
    } catch (e) {
      debugPrint('SharedPreferences deleteToken error: $e');
    }
  }

  Future<List<dynamic>> fetchEmployees({
    String? role,
    String? department,
    bool? isActive,
  }) async {
    String query = '';
    final List<String> params = [];
    if (role != null) params.add('role=$role');
    if (department != null) params.add('department=$department');
    if (isActive != null) params.add('isActive=$isActive');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    final response = await get('/admin/users$query');
    return response['users']; // Controller returns { users: [...] }
  }

  Future<void> addEmployee(Map<String, dynamic> data) async {
    await post('/admin/users', data);
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    await put('/admin/users/$id', data);
  }

  Future<void> addTeamMember(int teamId, int userId) async {
    await post('/admin/teams/add-member', {
      'teamId': teamId,
      'userId': userId,
    });
  }

  Future<void> deleteUser(int id) async {
    await delete('/admin/users/$id');
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await get('/auth/me');
  }

  Future<void> logout() async {
    try {
      await post('/auth/logout', {});
    } catch (_) {
      // Ignore errors during logout (e.g. if token is already invalid)
    }
    await deleteToken();
  }

  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    return await post('/auth/change-password', {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> updateProfilePicture(String profilePicture) async {
    return await put('/auth/profile-picture', {
      'profilePicture': profilePicture,
    });
  }

  Future<Map<String, dynamic>> deleteProfilePicture() async {
    return await delete('/auth/profile-picture');
  }

  // Attendance & Stats
  Future<void> checkIn(Map<String, dynamic> data) async {
    await post('/attendance/check-in', data);
  }

  Future<void> checkOut(Map<String, dynamic> data) async {
    await post('/attendance/check-out', data);
  }

  Future<Map<String, dynamic>> getTodayAttendance() async {
    return await get('/attendance/today');
  }

  Future<Map<String, dynamic>> getMyAttendance({
    String? startDate,
    String? endDate,
    int? month,
    int? year,
  }) async {
    String query = '';
    final List<String> params = [];
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    return await get('/attendance/my$query');
  }

  Future<Map<String, dynamic>> getAllAttendance({
    String? startDate,
    String? endDate,
    int? userId,
    String? employeeId,
    int? month,
    int? year,
  }) async {
    String query = '';
    final List<String> params = [];
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (userId != null) params.add('userId=$userId');
    if (employeeId != null) params.add('employeeId=$employeeId');
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    return await get('/attendance$query');
  }

  Future<Map<String, dynamic>> getAttendanceByTeams({
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    String query = '';
    final List<String> params = [];
    if (date != null) params.add('date=$date');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (params.isNotEmpty) query = '?${params.join('&')}';
    return await get('/attendance/by-teams$query');
  }

  Future<Map<String, dynamic>> getAttendanceStats({
    String? startDate,
    String? endDate,
    int? userId,
  }) async {
    String query = '';
    final List<String> params = [];
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (userId != null) params.add('userId=$userId');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    return await get('/admin/attendance/stats$query');
  }

  Future<Map<String, dynamic>> getUserStats() async {
    return await get('/attendance/stats');
  }

  Future<String> exportAttendanceReport({
    String? startDate,
    String? endDate,
    int? userId,
  }) async {
    String query = '';
    final List<String> params = [];
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    if (userId != null) params.add('userId=$userId');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    final response = await http.get(
      Uri.parse('$baseUrl/admin/reports/export$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    } else {
      try {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to export report');
      } catch (_) {
        throw Exception('Failed to export report: ${response.statusCode}');
      }
    }
  }

  // Location
  Future<Map<String, dynamic>> validateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await get(
      '/location/validate?latitude=$latitude&longitude=$longitude',
    );
    return response;
  }

  Future<Map<String, dynamic>> getOfficeLocation() async {
    return await get('/location/office-location');
  }

  // Upload
  Future<Map<String, dynamic>> uploadSelfie(XFile file) async {
    final fullUrl = '$baseUrl/upload/selfie';
    try {
      final uri = Uri.parse(fullUrl);
      final request = http.MultipartRequest('POST', uri);

      // Add Authorization header manually (avoid _getHeaders which adds JSON Content-Type)
      final token = await getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add file with explicit Content-Type and ensure filename has an extension
      final mimeType = _getMediaType(file.name);
      String fileName = file.name.isEmpty
          ? 'upload_${DateTime.now().millisecondsSinceEpoch}'
          : file.name;

      // On Web, file.name might be 'blob' or have no extension, which multer might reject
      if (!fileName.contains('.')) {
        fileName = '$fileName.jpg';
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'selfie',
            bytes,
            filename: fileName,
            contentType: mimeType,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'selfie',
            file.path,
            filename: fileName,
            contentType: mimeType,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final result = _processResponse(response);
      return Map<String, dynamic>.from(result);
    } catch (e) {
      if (e is ApiException) rethrow;

      String userMessage = 'Unable to upload selfie.';
      String devDetails = 'Error: $e\nAttempted URL: $fullUrl';

      if (e is TimeoutException) {
        userMessage = 'The selfie upload timed out. The file might be too large or the server is slow.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Connection refused') || 
                 e.toString().contains('Failed host lookup')) {
        userMessage = 'Cannot reach the server for upload. Please check your internet connection or server status.';
      }

      final apiException = ApiException(
        userMessage: userMessage,
        devDetails: devDetails,
        url: fullUrl,
      );
      lastApiException = apiException;
      throw apiException;
    }
  }

  /// Upload a profile picture to the dedicated Jimp-processed endpoint.
  /// Accepts images up to 3 MB. Returns { url, filename }.
  Future<Map<String, dynamic>> uploadProfilePicture(XFile file) async {
    final fullUrl = '$baseUrl/upload/profile-picture';
    try {
      final uri = Uri.parse(fullUrl);
      final request = http.MultipartRequest('POST', uri);

      final token = await getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final mimeType = _getMediaType(file.name);
      String fileName = file.name.isEmpty
          ? 'profile_${DateTime.now().millisecondsSinceEpoch}'
          : file.name;

      if (!fileName.contains('.')) {
        fileName = '$fileName.jpg';
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePicture',
            bytes,
            filename: fileName,
            contentType: mimeType,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profilePicture',
            file.path,
            filename: fileName,
            contentType: mimeType,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final result = _processResponse(response);
      return Map<String, dynamic>.from(result);
    } catch (e) {
      if (e is ApiException) rethrow;

      String userMessage = 'Unable to upload profile picture.';
      String devDetails = 'Error: $e\nAttempted URL: $fullUrl';

      if (e is TimeoutException) {
        userMessage = 'The profile picture upload timed out. The file might be too large or the server is slow.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Connection refused') || 
                 e.toString().contains('Failed host lookup')) {
        userMessage = 'Cannot reach the server for upload. Please check your internet connection or server status.';
      }

      final apiException = ApiException(
        userMessage: userMessage,
        devDetails: devDetails,
        url: fullUrl,
      );
      lastApiException = apiException;
      throw apiException;
    }
  }


  MediaType _getMediaType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'bf': // Bug fix: some devices use bf for bmp or raw? Unlikely.
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        // Default fallback
        return MediaType('image', 'jpeg');
    }
  }

  // Leaves System API integrations
  Future<List<dynamic>> fetchMyLeaves() async {
    final response = await get('/leaves/my');
    return response['leaves'];
  }

  Future<List<dynamic>> fetchAllLeaves({int? userId}) async {
    String query = '';
    if (userId != null) query = '?userId=$userId';
    final response = await get('/leaves/admin$query');
    return response['leaves'];
  }

  Future<void> applyLeave(Map<String, dynamic> data) async {
    await post('/leaves/apply', data);
  }

  Future<void> updateLeaveStatus(int id, String status, String? adminComment) async {
    await put('/leaves/admin/$id', {
      'status': status,
      if (adminComment != null) 'adminComment': adminComment,
    });
  }

  Future<void> updateLeave(int id, Map<String, dynamic> data) async {
    await put('/leaves/update/$id', data);
  }

  // Location Tracking APIs
  Future<List<dynamic>> getMarketingTrail(int userId, {String? date}) async {
    String endpoint = '/location/trail/$userId';
    if (date != null) {
      endpoint += '?date=$date';
    }
    final response = await get(endpoint);
    return response['logs'];
  }

  Future<List<dynamic>> getActiveMarketingEmployees() async {
    final response = await get('/location/active');
    return response['activeEmployees'];
  }

  Future<List<dynamic>> getAllMarketingEmployees() async {
    final response = await get('/location/all-marketing');
    return response['employees'];
  }

  // Team Management APIs
  Future<List<dynamic>> fetchTeams() async {
    final response = await get('/admin/teams');
    return response['teams'];
  }

  Future<void> createTeam(Map<String, dynamic> data) async {
    await post('/admin/teams', data);
  }

  Future<void> updateTeam(int id, Map<String, dynamic> data) async {
    await put('/admin/teams/$id', data);
  }

  Future<void> deleteTeam(int id) async {
    await delete('/admin/teams/$id');
  }

  // ── Holiday Management APIs ────────────────────────────────────────────────

  Future<List<dynamic>> fetchHolidays({int? month, int? year}) async {
    String query = '';
    final List<String> params = [];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    if (params.isNotEmpty) query = '?${params.join('&')}';
    final response = await get('/holidays$query');
    return response['holidays'];
  }

  Future<void> createHoliday(Map<String, dynamic> data) async {
    await post('/holidays', data);
  }

  Future<void> updateHoliday(int id, Map<String, dynamic> data) async {
    await put('/holidays/$id', data);
  }

  Future<void> deleteHoliday(int id) async {
    await delete('/holidays/$id');
  }

  Future<List<dynamic>> parseHolidaySheet(XFile file) async {
    final fullUrl = '$baseUrl/holidays/parse-sheet';
    try {
      final uri = Uri.parse(fullUrl);
      final request = http.MultipartRequest('POST', uri);

      final token = await getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      String fileName = file.name.isEmpty
          ? 'holiday_sheet_${DateTime.now().millisecondsSinceEpoch}'
          : file.name;
      if (!fileName.contains('.')) fileName = '$fileName.xlsx';

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'sheet',
            bytes,
            filename: fileName,
            contentType: MediaType('application', 'octet-stream'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'sheet',
            file.path,
            filename: fileName,
            contentType: MediaType('application', 'octet-stream'),
          ),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final result = _processResponse(response);
      return result['parsed'];
    } catch (e) {
      if (e is ApiException) rethrow;

      String userMessage = 'Unable to upload and parse holiday sheet.';
      String devDetails = 'Error: $e\nAttempted URL: $fullUrl';

      if (e is TimeoutException) {
        userMessage = 'The sheet upload timed out. The file might be too large or the server is slow.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Connection refused') || 
                 e.toString().contains('Failed host lookup')) {
        userMessage = 'Cannot reach the server for upload. Please check your internet connection or server status.';
      }

      final apiException = ApiException(
        userMessage: userMessage,
        devDetails: devDetails,
        url: fullUrl,
      );
      lastApiException = apiException;
      throw apiException;
    }
  }

  Future<List<dynamic>> bulkCreateHolidays(List<Map<String, dynamic>> holidays) async {
    final response = await post('/holidays/bulk', {'holidays': holidays});
    return response['holidays'];
  }

  Future<List<dynamic>> fetchHolidayExceptions(int holidayId) async {
    final response = await get('/holidays/$holidayId/exceptions');
    return response['exceptions'];
  }

  Future<void> addHolidayException(int holidayId, Map<String, dynamic> data) async {
    await post('/holidays/$holidayId/exceptions', data);
  }

  Future<void> removeHolidayException(int holidayId, int exceptionId) async {
    await delete('/holidays/$holidayId/exceptions/$exceptionId');
  }

  Future<Map<String, dynamic>> fetchCompanySettings() async {
    final response = await get('/admin/company-settings');
    return response;
  }

  Future<Map<String, dynamic>> updateCompanySettings(Map<String, dynamic> data) async {
    final response = await put('/admin/company-settings', data);
    return response;
  }

  // ── Company Management (System Admin only) ───────────────────────────────

  /// Fetch all registered companies with admin + stats details.
  Future<List<dynamic>> fetchCompanies() async {
    final response = await get('/admin/companies');
    return response['companies'];
  }

  /// Register a new company and optionally its first admin account.
  Future<Map<String, dynamic>> createCompany({
    required String name,
    String? adminName,
    String? adminEmail,
    String? adminPassword,
  }) async {
    final response = await post('/admin/companies', {
      'name': name,
      if (adminName != null && adminName.isNotEmpty) 'adminName': adminName,
      if (adminEmail != null && adminEmail.isNotEmpty) 'adminEmail': adminEmail,
      if (adminPassword != null && adminPassword.isNotEmpty) 'adminPassword': adminPassword,
    });
    return response;
  }

  /// Log user coordinates to the location trail
  Future<Map<String, dynamic>> logLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    return await post('/location/log', {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
    });
  }
}

