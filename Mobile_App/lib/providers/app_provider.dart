// ignore_for_file: unnecessary_import
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/user.dart';
import '../models/attendance.dart';
import '../models/holiday.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';


class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  String? _companyLogoUrl;
  String? get companyLogoUrl => _companyLogoUrl;

  final List<User> _employees = [];
  final List<Attendance> _attendance = [];
  Map<String, dynamic> _attendanceStats = {'totalUsers': 0};
  Map<String, dynamic> _userStats = {'present': 0, 'absents': 0, 'halfDay': 0};

  bool _excludeWeekends = true;
  bool get excludeWeekends => _excludeWeekends;
  set excludeWeekends(bool value) {
    if (_excludeWeekends != value) {
      _excludeWeekends = value;
      _calculateLocalStats();
      notifyListeners();
    }
  }

  int? _lastStatsMonth;
  int? _lastStatsYear;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<dynamic> _marketingTrail = [];
  List<dynamic> get marketingTrail => _marketingTrail;

  List<dynamic> _activeMarketingEmployees = [];
  List<dynamic> get activeMarketingEmployees => _activeMarketingEmployees;

  final List<User> _marketingEmployees = [];
  List<User> get marketingEmployees => _marketingEmployees;

  List<dynamic> _allMarketingEmployees = [];
  List<dynamic> get allMarketingEmployees => _allMarketingEmployees;

  Map<String, dynamic>? _selectedEmployeeAttendance;
  Map<String, dynamic>? get selectedEmployeeAttendance => _selectedEmployeeAttendance;

  Map<String, dynamic> get attendanceStats => _attendanceStats;

  Map<String, dynamic> get userStats => _userStats;

  String? _currentAddress;
  String? get currentAddress => _currentAddress;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // --- Employee Management ---
  List<User> get employees => _employees;

  /// Safe notifyListeners that defers the call if we are currently in the
  /// build/layout phase (prevents the "setState called during build" crash).
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // We are inside a build frame — defer to the next frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> fetchEmployees({String? role}) async {
    _isLoading = true;
    _safeNotify();
    try {
      // Fetch all users (no role filter) so managers, TLs, and admins also show up
      final List<dynamic> usersJson = await _apiService.fetchEmployees();
      _employees.clear();
      _employees.addAll(usersJson.map((json) => User.fromJson(json)).toList());
    } catch (e) {
      debugPrint("Error fetching employees: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCompanyLogo() async {
    try {
      final List<dynamic> usersJson = await _apiService.fetchEmployees(role: 'company_admin');
      if (usersJson.isNotEmpty) {
        final adminUser = usersJson.first;
        final String? picPath = adminUser['profilePicture'];
        if (picPath != null && picPath.isNotEmpty) {
          _companyLogoUrl = picPath;
        } else {
          _companyLogoUrl = null;
        }
      } else {
        // Fallback: search system_admin if no company_admin is found
        final List<dynamic> systemAdmins = await _apiService.fetchEmployees(role: 'system_admin');
        if (systemAdmins.isNotEmpty) {
          final sysAdmin = systemAdmins.first;
          final String? picPath = sysAdmin['profilePicture'];
          if (picPath != null && picPath.isNotEmpty) {
            _companyLogoUrl = picPath;
          } else {
            _companyLogoUrl = null;
          }
        } else {
          _companyLogoUrl = null;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching company logo: $e");
    }
  }

  Future<void> fetchUserStats() async {
    try {
      final now = DateTime.now();
      await fetchMyAttendance(month: now.month, year: now.year, showLoading: false);
    } catch (e) {
      debugPrint("Error fetching user stats: $e");
    }
  }

  void _calculateLocalStats({int? month, int? year}) {
    if (month != null) _lastStatsMonth = month;
    if (year != null) _lastStatsYear = year;

    final now = DateTime.now();
    final int targetMonth = month ?? _lastStatsMonth ?? now.month;
    final int targetYear = year ?? _lastStatsYear ?? now.year;

    int present = 0;
    int absents = 0;
    int halfDay = 0;
    int leaveCount = 0;

    int maxDay;
    if (targetYear == now.year && targetMonth == now.month) {
      maxDay = now.day;
    } else if (targetYear < now.year || (targetYear == now.year && targetMonth < now.month)) {
      maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
    } else {
      maxDay = 0;
    }

    // Build a Set of date strings that are covered by approved leaves
    final Set<String> approvedLeaveDates = {};
    for (final leave in _leaves) {
      if (leave is! Map) continue;
      final leaveMap = leave as Map<String, dynamic>;
      final status = (leaveMap['status'] ?? '').toString().toLowerCase();
      if (status != 'approved') continue;
      final startStr = leaveMap['startDate']?.toString() ?? '';
      final endStr = leaveMap['endDate']?.toString() ?? '';
      if (startStr.isEmpty || endStr.isEmpty) continue;
      try {
        final start = DateTime.parse(startStr);
        final end = DateTime.parse(endStr);
        for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
          if (d.year == targetYear && d.month == targetMonth) {
            approvedLeaveDates.add(
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
            );
          }
        }
      } catch (_) {}
    }

    // Calculate total leaves for the ENTIRE selected month (including future days)
    final int totalDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    for (int day = 1; day <= totalDaysInMonth; day++) {
      final dateStr =
          '$targetYear-${targetMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      if (approvedLeaveDates.contains(dateStr)) {
        leaveCount++;
      }
    }

    for (int day = 1; day <= maxDay; day++) {
      final dateToCheck = DateTime(targetYear, targetMonth, day);
      final dateStr =
          '$targetYear-${targetMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final isWeekend = dateToCheck.weekday == DateTime.saturday || dateToCheck.weekday == DateTime.sunday;
      final isOnLeave = approvedLeaveDates.contains(dateStr);

      final dayRecords = _attendance.where((a) {
        try {
          final attendanceDate = DateTime.parse(a.date);
          return attendanceDate.year == targetYear &&
              attendanceDate.month == targetMonth &&
              attendanceDate.day == day;
        } catch (e) {
          return false;
        }
      }).toList();

      if (isOnLeave) {
        // Already counted in total leaves above. Skip marking as absent/present/halfday.
      } else if (dayRecords.isNotEmpty) {
        final hasCheckout = dayRecords.any((r) => r.checkOutTime != null);
        if (hasCheckout) {
          present++;
        } else {
          halfDay++;
        }
      } else {
        if (!_excludeWeekends || !isWeekend) {
          absents++;
        }
      }
    }

    _userStats = {
      'present': present,
      'absents': absents,
      'halfDay': halfDay,
      'leaves': leaveCount,
    };
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await _apiService.changePassword(oldPassword, newPassword);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addEmployee(
    String name,
    String email,
    String employeeId,
    String department,
    String password,
    String role, {
    String? dob,
    String? state,
    String? city,
    String? workMode,
    String? workType,
    String? profilePicture,
    int? teamId,
  }) async {
    try {
      await _apiService.addEmployee({
        'name': name,
        'email': email,
        'employeeId': employeeId,
        'department': department,
        'password': password,
        'role': role,
        if (dob != null) 'dob': dob,
        if (state != null) 'state': state,
        if (city != null) 'city': city,
        if (workMode != null) 'workMode': workMode,
        if (workType != null) 'workType': workType,
        if (profilePicture != null) 'profilePicture': profilePicture,
        if (teamId != null) 'teamId': teamId,
      });
      await fetchEmployees();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEmployee(int id, Map<String, dynamic> data) async {
    try {
      await _apiService.updateUser(id, data);
      await fetchEmployees();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteEmployee(int id) async {
    try {
      await _apiService.deleteUser(id);
      await fetchEmployees();
    } catch (e) {
      debugPrint("Error deleting employee: $e");
      rethrow;
    }
  }

  // --- Attendance Management ---
  List<Attendance> get attendance => _attendance;

  List<Attendance> getAttendanceForDate(DateTime date) {
    return _attendance.where((a) {
      final attendanceDate = DateTime.parse(a.date);
      return attendanceDate.year == date.year &&
          attendanceDate.month == date.month &&
          attendanceDate.day == date.day;
    }).toList();
  }

  Attendance? _todayAttendance;
  Attendance? get todayAttendance => _todayAttendance;

  Future<void> fetchTodayAttendance() async {
    try {
      final response = await _apiService.getTodayAttendance();
      if (response['attendance'] != null) {
        _todayAttendance = Attendance.fromJson(response['attendance']);
      } else {
        _todayAttendance = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching today's attendance: $e");
    }
  }

  Future<void> fetchMyAttendance({
    int? month,
    int? year,
    String? startDate,
    String? endDate,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      _safeNotify();
    }
    try {
      final response = await _apiService.getMyAttendance(
        month: month,
        year: year,
        startDate: startDate,
        endDate: endDate,
      );
      final List<dynamic> data = response['attendance'];
      _attendance.clear();
      _attendance.addAll(
        data.map((json) => Attendance.fromJson(json)).toList(),
      );
      if (month != null && year != null) {
        _calculateLocalStats(month: month, year: year);
      }
    } catch (e) {
      debugPrint("Error fetching my attendance: $e");
    } finally {
      if (showLoading) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }



    // Face verification removed

  Future<void> checkIn({
    XFile? selfieFile,
    String? selfieUrl,
    required double lat,
    required double long,
    String? address,
    String status = 'success',
    String? mood,
    String? energyLevel,
  }) async {
    try {
      String? finalSelfieUrl = selfieUrl;
      if (selfieFile != null) {
        final uploadResponse = await _apiService.uploadSelfie(selfieFile);
        finalSelfieUrl = uploadResponse['url'];
      }
      final truncatedAddress = (address != null && address.length > 255)
          ? address.substring(0, 255)
          : address;
      await _apiService.checkIn({
        if (finalSelfieUrl != null && finalSelfieUrl.isNotEmpty)
          'selfieUrl': finalSelfieUrl,
        'latitude': lat,
        'longitude': long,
        'address': truncatedAddress,
        'loginStatus': status,
        if (mood != null) 'mood': mood,
        if (energyLevel != null) 'energyLevel': energyLevel,
      });
      await fetchTodayAttendance();
      await fetchUserStats();

      // Trigger background tracking only for Marketing department employees with Field Work or Office + Field Work
      try {
        final user = await AuthService().getUser();
        if (!kIsWeb && user != null &&
            user.department?.toLowerCase() == 'marketing' &&
            (user.workType == 'Field Work' || user.workType == 'Office + Field Work')) {
          final service = FlutterBackgroundService();
          final isRunning = await service.isRunning();
          if (!isRunning) {
            await service.startService();
          }
        }
      } catch (e) {
        debugPrint("Error starting background tracking service: $e");
      }
    } catch (e) {
      rethrow;
    }

  }

  Future<void> checkOut({
    required int attendanceId,
    XFile? checkoutSelfieFile,
    String? checkoutSelfieUrl,
    required double lat,
    required double long,
    String? address,
    String status = 'success',
    String? taskComments,
  }) async {
    try {
      String? finalSelfieUrl = checkoutSelfieUrl;
      if (checkoutSelfieFile != null) {
        final uploadResponse = await _apiService.uploadSelfie(
          checkoutSelfieFile,
        );
        finalSelfieUrl = uploadResponse['url'];
      }
      final truncatedAddress = (address != null && address.length > 255)
          ? address.substring(0, 255)
          : address;
      await _apiService.checkOut({
        'attendanceId': attendanceId,
        if (finalSelfieUrl != null && finalSelfieUrl.isNotEmpty)
          'checkoutSelfieUrl': finalSelfieUrl,
        'checkoutLatitude': lat,
        'checkoutLongitude': long,
        'checkoutAddress': truncatedAddress,
        'logoutStatus': status,
        if (taskComments != null) 'taskComments': taskComments,
      });
      await fetchTodayAttendance();
      await fetchUserStats();

      try {
        if (!kIsWeb) {
          final service = FlutterBackgroundService();
          final isRunning = await service.isRunning();
          if (isRunning) {
            service.invoke('stopService');
          }
        }
      } catch (e) {
        debugPrint("Error stopping background tracking service: $e");
      }
    } catch (e) {
      rethrow;
    }

  }

  Future<void> fetchAllAttendance({
    String? startDate,
    String? endDate,
    int? userId,
    String? employeeId,
    int? month,
    int? year,
  }) async {
    _isLoading = true;
    _safeNotify();
    try {
      final response = await _apiService.getAllAttendance(
        startDate: startDate,
        endDate: endDate,
        userId: userId,
        employeeId: employeeId,
        month: month,
        year: year,
      );
      final List<dynamic> data = response['attendance'];
      _attendance.clear();
      _attendance.addAll(
        data.map((json) => Attendance.fromJson(json)).toList(),
      );
    } catch (e) {
      debugPrint("Error fetching all attendance: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Team-grouped attendance
  List<dynamic> _attendanceByTeams = [];
  List<dynamic> get attendanceByTeams => _attendanceByTeams;

  Future<void> fetchAttendanceByTeams({String? date, String? startDate, String? endDate}) async {
    _isLoading = true;
    _safeNotify();
    try {
      final response = await _apiService.getAttendanceByTeams(
        date: date,
        startDate: startDate,
        endDate: endDate,
      );
      _attendanceByTeams = response['grouped'] ?? [];
    } catch (e) {
      debugPrint("Error fetching team attendance: $e");
      _attendanceByTeams = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStats({
    String? startDate,
    String? endDate,
    int? userId,
  }) async {
    try {
      final stats = await _apiService.getAttendanceStats(
        startDate: startDate,
        endDate: endDate,
        userId: userId,
      );
      _attendanceStats = stats;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  // --- Location Service ---
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }
    return true;
  }

  Future<void> getCurrentPosition() async {
    await handleLocationPermission();
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20), // ✅ Prevent indefinite hang on weak GPS signal
        ),
      );
      // ✅ FIX: Set position FIRST before geocoding so a geocoding crash never loses the GPS fix
      _currentPosition = position;
      notifyListeners();

      // Reverse geocoding is best-effort — failure must NOT block check-in
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 10));
        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks[0];
          final rawAddress =
              "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
          _currentAddress = rawAddress.length > 255
              ? rawAddress.substring(0, 255)
              : rawAddress;
          notifyListeners();
        }
      } catch (geocodeError) {
        // Geocoding failed (no network or no Google Play Services) — use coordinates as address
        _currentAddress =
            "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        debugPrint("Geocoding failed (non-fatal): $geocodeError");
        notifyListeners();
      }
    } on TimeoutException catch (_) {
      debugPrint("GPS timed out after 20 seconds.");
      // Leave _currentPosition null so the capture screen shows the right error
    } catch (e) {
      debugPrint("Error getting location: $e");
      rethrow; // Re-throw so the capture screen can show the exact location error
    }
  }

  void setManualAddress(String address) {
    _currentAddress = address.length > 255 ? address.substring(0, 255) : address;
    _currentPosition = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.logout();
    _employees.clear();
    _attendance.clear();
    _todayAttendance = null;
    _leaves.clear();
    notifyListeners();
  }

  // --- Leaves Management ---
  final List<dynamic> _leaves = [];
  List<dynamic> get leaves => _leaves;

  Future<void> fetchMyLeaves() async {
    _isLoading = true;
    _safeNotify();
    try {
      final data = await _apiService.fetchMyLeaves();
      _leaves.clear();
      _leaves.addAll(data);
      _calculateLocalStats();
    } catch (e) {
      debugPrint("Error fetching my leaves: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllLeaves() async {
    _isLoading = true;
    _safeNotify();
    try {
      final data = await _apiService.fetchAllLeaves();
      _leaves.clear();
      _leaves.addAll(data);
    } catch (e) {
      debugPrint("Error fetching all leaves: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyLeave(String startDate, String endDate, String reason) async {
    try {
      await _apiService.applyLeave({
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
      });
      await fetchMyLeaves();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLeaveStatus(int id, String status, String? adminComment) async {
    try {
      await _apiService.updateLeaveStatus(id, status, adminComment);
      await fetchAllLeaves();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLeave(int id, String startDate, String endDate, String reason) async {
    try {
      await _apiService.updateLeave(id, {
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
      });
      await fetchMyLeaves();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchMarketingTrail(int userId, {String? date}) async {
    _isLoading = true;
    _safeNotify();
    try {
      final logs = await _apiService.getMarketingTrail(userId, date: date);
      _marketingTrail = logs;
    } catch (e) {
      debugPrint("Error fetching marketing trail: $e");
      _marketingTrail = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchActiveMarketingEmployees() async {
    _isLoading = true;
    _safeNotify();
    try {
      final employees = await _apiService.getActiveMarketingEmployees();
      _activeMarketingEmployees = employees;
    } catch (e) {
      debugPrint("Error fetching active marketing list: $e");
      _activeMarketingEmployees = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all marketing department employees with today's check-in/location status
  Future<void> fetchAllMarketingEmployees() async {
    _isLoading = true;
    _safeNotify();
    try {
      final data = await _apiService.getAllMarketingEmployees();
      _allMarketingEmployees = data;
    } catch (e) {
      debugPrint("Error fetching all marketing employees: $e");
      _allMarketingEmployees = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Team Management Provider methods
  final List<dynamic> _teams = [];
  List<dynamic> get teams => _teams;

  Future<void> fetchTeams() async {
    _isLoading = true;
    _safeNotify();
    try {
      final data = await _apiService.fetchTeams();
      _teams.clear();
      _teams.addAll(data);
    } catch (e) {
      debugPrint("Error fetching teams: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTeam(String name) async {
    try {
      await _apiService.createTeam({'name': name});
      await fetchTeams();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTeam(int id, {
    String? name,
    int? managerId,
    int? teamLeaderId,
    bool clearManager = false,
    bool clearTeamLeader = false,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (managerId != null) {
        data['managerId'] = managerId;
      } else if (clearManager) {
        data['managerId'] = null;
      }
      if (teamLeaderId != null) {
        data['teamLeaderId'] = teamLeaderId;
      } else if (clearTeamLeader) {
        data['teamLeaderId'] = null;
      }

      await _apiService.updateTeam(id, data);
      await fetchTeams();
      await fetchEmployees();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTeam(int id) async {
    try {
      await _apiService.deleteTeam(id);
      await fetchTeams();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignUserToTeam(int userId, int? teamId, {String? role}) async {
    try {
      final Map<String, dynamic> updateData = {'teamId': teamId};
      if (role != null) {
        updateData['role'] = role;
      }
      await _apiService.updateUser(userId, updateData);
      await fetchTeams();
      await fetchEmployees();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addTeamMember(int teamId, int userId) async {
    try {
      await _apiService.addTeamMember(teamId, userId);
      await fetchTeams();
      await fetchEmployees();
    } catch (e) {
      rethrow;
    }
  }

  // ── Holiday Management ─────────────────────────────────────────────────────
  final List<Holiday> _holidays = [];
  List<Holiday> get holidays => _holidays;

  Future<void> fetchHolidays({int? month, int? year}) async {
    try {
      final data = await _apiService.fetchHolidays(month: month, year: year);
      _holidays.clear();
      _holidays.addAll(data.map((h) => Holiday.fromJson(h)).toList());
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching holidays: $e");
    }
  }

  Future<void> createHoliday(String date, String name) async {
    try {
      await _apiService.createHoliday({'date': date, 'name': name});
      await fetchHolidays(year: DateTime.parse(date).year);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteHoliday(int id) async {
    try {
      await _apiService.deleteHoliday(id);
      _holidays.removeWhere((h) => h.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> parseHolidaySheet(XFile file) async {
    try {
      final raw = await _apiService.parseHolidaySheet(file);
      return raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> bulkCreateHolidays(List<Map<String, dynamic>> holidays) async {
    try {
      await _apiService.bulkCreateHolidays(holidays);
      // Refresh for current year
      await fetchHolidays(year: DateTime.now().year);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addHolidayException(int holidayId, Map<String, dynamic> data) async {
    try {
      await _apiService.addHolidayException(holidayId, data);
      await fetchHolidays(year: DateTime.now().year);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeHolidayException(int holidayId, int exceptionId) async {
    try {
      await _apiService.removeHolidayException(holidayId, exceptionId);
      await fetchHolidays(year: DateTime.now().year);
    } catch (e) {
      rethrow;
    }
  }

  /// Returns true if the given date is a company holiday
  bool isHoliday(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _holidays.any((h) => h.date == dateStr && h.isActive);
  }

  /// Returns the holiday for a given date, or null
  Holiday? getHolidayForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      return _holidays.firstWhere((h) => h.date == dateStr && h.isActive);
    } catch (_) {
      return null;
    }
  }

  // --- Company Settings State ---
  String? _checkInTime;
  String? get checkInTime => _checkInTime;

  String? _checkOutTime;
  String? get checkOutTime => _checkOutTime;

  double? _officeLatitude;
  double? get officeLatitude => _officeLatitude;

  double? _officeLongitude;
  double? get officeLongitude => _officeLongitude;

  String? _officeAddress;
  String? get officeAddress => _officeAddress;

  double? _geofencingRadius;
  double? get geofencingRadius => _geofencingRadius;

  Future<void> fetchCompanySettings() async {
    _isLoading = true;
    _safeNotify();
    try {
      final response = await _apiService.fetchCompanySettings();
      if (response['settings'] != null) {
        final s = response['settings'];
        _checkInTime = s['checkInTime'] ?? s['check_in_time'];
        _checkOutTime = s['checkOutTime'] ?? s['check_out_time'];
        _officeLatitude = s['latitude'] != null ? double.tryParse(s['latitude'].toString()) : null;
        _officeLongitude = s['longitude'] != null ? double.tryParse(s['longitude'].toString()) : null;
        _officeAddress = s['address'];
        _geofencingRadius = s['radius'] != null ? double.tryParse(s['radius'].toString()) : null;
      }
    } catch (e) {
      debugPrint("Error fetching company settings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCompanySettings({
    String? checkInTime,
    String? checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    double? radius,
  }) async {
    _isLoading = true;
    _safeNotify();
    try {
      final response = await _apiService.updateCompanySettings({
        if (checkInTime != null) 'checkInTime': checkInTime,
        if (checkOutTime != null) 'checkOutTime': checkOutTime,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null) 'address': address,
        if (radius != null) 'radius': radius,
      });
      if (response['settings'] != null) {
        final s = response['settings'];
        _checkInTime = s['checkInTime'] ?? s['check_in_time'];
        _checkOutTime = s['checkOutTime'] ?? s['check_out_time'];
        _officeLatitude = s['latitude'] != null ? double.tryParse(s['latitude'].toString()) : null;
        _officeLongitude = s['longitude'] != null ? double.tryParse(s['longitude'].toString()) : null;
        _officeAddress = s['address'];
        _geofencingRadius = s['radius'] != null ? double.tryParse(s['radius'].toString()) : null;
      }
    } catch (e) {
      debugPrint("Error updating company settings: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
