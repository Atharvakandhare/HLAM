import 'user.dart';

class Attendance {
  final int id;
  final int userId;
  final String date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String selfieUrl;
  final String? checkoutSelfieUrl;
  final String? taskComments;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? checkoutLatitude;
  final double? checkoutLongitude;
  final String? checkoutAddress;
  final String status;
  final User? user;
  final String loginStatus;
  final String logoutStatus;
  final String? serverWorkingHours;
  final String? mood;
  final String? energyLevel;
  final double? distanceFromOffice;
  final int? shiftId;
  final bool isLateIn;
  final bool isLateOut;
  final bool isEarlyIn;
  final bool isEarlyOut;
  final bool overtimeAllowed;
  final String? overtimeDuration;

  Attendance({
    required this.id,
    required this.userId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.selfieUrl,
    this.checkoutSelfieUrl,
    this.taskComments,
    this.latitude,
    this.longitude,
    this.address,
    this.checkoutLatitude,
    this.checkoutLongitude,
    this.checkoutAddress,
    required this.status,
    this.user,
    this.loginStatus = 'pending',
    this.logoutStatus = 'pending',
    this.serverWorkingHours,
    this.mood,
    this.energyLevel,
    this.distanceFromOffice,
    this.shiftId,
    this.isLateIn = false,
    this.isLateOut = false,
    this.isEarlyIn = false,
    this.isEarlyOut = false,
    this.overtimeAllowed = false,
    this.overtimeDuration,
  });

  String get workingHours {
    if (checkInTime != null && checkOutTime == null) {
      final diff = DateTime.now().difference(checkInTime!);
      return _formatDuration(diff);
    }
    if (checkInTime != null && checkOutTime != null) {
      final diff = checkOutTime!.difference(checkInTime!);
      return _formatDuration(diff);
    }
    if (serverWorkingHours != null && serverWorkingHours!.isNotEmpty) {
      return serverWorkingHours!;
    }
    return '0h 0m';
  }

  String _formatDuration(Duration duration) {
    final hrs = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    return "${hrs}h ${mins}m";
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      userId: json['user_id'] ?? json['userId'],
      date: json['date'],
      checkInTime: json['check_in_time'] != null || json['checkInTime'] != null
          ? DateTime.parse(
              json['check_in_time'] ?? json['checkInTime'],
            ).toLocal()
          : null,
      checkOutTime:
          json['check_out_time'] != null || json['checkOutTime'] != null
          ? DateTime.parse(
              json['check_out_time'] ?? json['checkOutTime'],
            ).toLocal()
          : null,
      selfieUrl: json['selfie_url'] ?? json['selfieUrl'] ?? '',
      checkoutSelfieUrl:
          json['checkoutSelfieUrl'] ?? json['checkout_selfie_url'],
      taskComments: json['task_comments'] ?? json['taskComments'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      address: json['address'],
      checkoutLatitude:
          json['checkoutLatitude'] != null || json['checkout_latitude'] != null
          ? double.tryParse(
              (json['checkoutLatitude'] ?? json['checkout_latitude'])
                  .toString(),
            )
          : null,
      checkoutLongitude:
          json['checkoutLongitude'] != null ||
              json['checkout_longitude'] != null
          ? double.tryParse(
              (json['checkoutLongitude'] ?? json['checkout_longitude'])
                  .toString(),
            )
          : null,
      checkoutAddress: json['checkoutAddress'] ?? json['checkout_address'],
      status: json['status'] ?? 'present',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      loginStatus: _normalizeStatus(
        json['loginStatus'] ?? json['login_status'],
        json['checkInTime'] ?? json['check_in_time'],
      ),
      logoutStatus: _normalizeStatus(
        json['logoutStatus'] ?? json['logout_status'],
        json['checkOutTime'] ?? json['check_out_time'],
      ),
      serverWorkingHours: json['workingHours'] ?? json['working_hours'],
      mood: json['mood'],
      energyLevel: json['energyLevel'] ?? json['energy_level'],
      distanceFromOffice: json['distanceFromOffice'] != null || json['distance_from_office'] != null
          ? double.tryParse((json['distanceFromOffice'] ?? json['distance_from_office']).toString())
          : null,
      shiftId: json['shiftId'] ?? json['shift_id'],
      isLateIn: json['isLateIn'] == true || json['is_late_in'] == true || json['isLateIn'] == 1 || json['is_late_in'] == 1,
      isLateOut: json['isLateOut'] == true || json['is_late_out'] == true || json['isLateOut'] == 1 || json['is_late_out'] == 1,
      isEarlyIn: json['isEarlyIn'] == true || json['is_early_in'] == true || json['isEarlyIn'] == 1 || json['is_early_in'] == 1,
      isEarlyOut: json['isEarlyOut'] == true || json['is_early_out'] == true || json['isEarlyOut'] == 1 || json['is_early_out'] == 1,
      overtimeAllowed: json['overtimeAllowed'] == true || json['overtime_allowed'] == true || json['overtimeAllowed'] == 1 || json['overtime_allowed'] == 1,
      overtimeDuration: json['overtimeDuration'] ?? json['overtime_duration'],
    );
  }


  static String _normalizeStatus(dynamic status, dynamic time) {
    String s = (status ?? 'pending').toString().toLowerCase();
    if (s == 'pending' && time != null) {
      return 'success';
    }
    return s;
  }
}
