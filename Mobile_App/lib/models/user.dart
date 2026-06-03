class User {
  final int id;
  final String name;
  final String email;
  final String role; // 'system_admin', 'company_admin', 'manager', 'team_leader', 'employee'
  final String? department;
  final String? employeeId;
  final bool isActive;
  final String? profilePicture;
  final bool? isProfilePictureAdminSet;
  final int? companyId;
  final int? teamId;
  final String? dob;
  final String? state;
  final String? city;
  final String? workMode;
  final String? workType;
  
  // Nested structures mapped for easier access
  final String? companyName;
  final String? companyCheckInTime;
  final String? companyCheckOutTime;
  final double? companyLatitude;
  final double? companyLongitude;
  final double? companyRadius;
  final String? companyAddress;
  final String? teamName;
  final String? managerName;
  final String? teamLeaderName;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department,
    this.employeeId,
    this.isActive = true,
    this.profilePicture,
    this.isProfilePictureAdminSet = false,
    this.companyId,
    this.teamId,
    this.dob,
    this.state,
    this.city,
    this.workMode,
    this.workType,
    this.companyName,
    this.companyCheckInTime,
    this.companyCheckOutTime,
    this.companyLatitude,
    this.companyLongitude,
    this.companyRadius,
    this.companyAddress,
    this.teamName,
    this.managerName,
    this.teamLeaderName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper to extract nested company settings
    final companyMap = json['company'] as Map<String, dynamic>?;
    final settingsMap = companyMap?['settings'] as Map<String, dynamic>?;
    final teamMap = json['team'] as Map<String, dynamic>?;
    final managerMap = json['manager'] as Map<String, dynamic>?;
    final tlMap = json['teamLeader'] as Map<String, dynamic>?;

    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'employee',
      department: json['department'],
      employeeId: json['employee_id'] ?? json['employeeId'],
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['isActive'] == true ||
          json['isActive'] == 1 ||
          (json['is_active'] == null && json['isActive'] == null),
      profilePicture: json['profile_picture'] ?? json['profilePicture'],
      isProfilePictureAdminSet: json['is_profile_picture_admin_set'] == true ||
          json['is_profile_picture_admin_set'] == 1 ||
          json['isProfilePictureAdminSet'] == true ||
          json['isProfilePictureAdminSet'] == 1,
      companyId: json['companyId'] ?? json['company_id'],
      teamId: json['teamId'] ?? json['team_id'],
      dob: json['dob'],
      state: json['state'],
      city: json['city'],
      workMode: json['workMode'] ?? json['work_mode'],
      workType: json['workType'] ?? json['work_type'],
      
      companyName: companyMap?['name'],
      companyCheckInTime: settingsMap?['checkInTime'] ?? settingsMap?['check_in_time'],
      companyCheckOutTime: settingsMap?['checkOutTime'] ?? settingsMap?['check_out_time'],
      companyLatitude: settingsMap != null && settingsMap['latitude'] != null ? double.parse(settingsMap['latitude'].toString()) : null,
      companyLongitude: settingsMap != null && settingsMap['longitude'] != null ? double.parse(settingsMap['longitude'].toString()) : null,
      companyRadius: settingsMap != null && settingsMap['radius'] != null ? double.parse(settingsMap['radius'].toString()) : null,
      companyAddress: settingsMap?['address'],
      teamName: teamMap?['name'],
      managerName: managerMap?['name'],
      teamLeaderName: tlMap?['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'employeeId': employeeId,
      'isActive': isActive,
      'profilePicture': profilePicture,
      'isProfilePictureAdminSet': isProfilePictureAdminSet,
      'companyId': companyId,
      'teamId': teamId,
      'dob': dob,
      'state': state,
      'city': city,
      'workMode': workMode,
      'workType': workType,
      'companyName': companyName,
      'companyCheckInTime': companyCheckInTime,
      'companyCheckOutTime': companyCheckOutTime,
      'companyLatitude': companyLatitude,
      'companyLongitude': companyLongitude,
      'companyRadius': companyRadius,
      'companyAddress': companyAddress,
      'teamName': teamName,
      'managerName': managerName,
      'teamLeaderName': teamLeaderName,
    };
  }
}
