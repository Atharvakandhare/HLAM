class Shift {
  final int id;
  final int companyId;
  final String name;
  final String checkInTime;
  final String checkOutTime;
  final int lateInLimit;
  final int lateOutLimit;
  final int earlyInLimit;
  final int earlyOutLimit;
  final bool isActive;

  Shift({
    required this.id,
    required this.companyId,
    required this.name,
    required this.checkInTime,
    required this.checkOutTime,
    required this.lateInLimit,
    required this.lateOutLimit,
    required this.earlyInLimit,
    required this.earlyOutLimit,
    required this.isActive,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      companyId: (json['companyId'] ?? json['company_id']) as int,
      name: json['name'] as String,
      checkInTime: json['checkInTime'] ?? json['check_in_time'] ?? '',
      checkOutTime: json['checkOutTime'] ?? json['check_out_time'] ?? '',
      lateInLimit: (json['lateInLimit'] ?? json['late_in_limit'] ?? 15) as int,
      lateOutLimit: (json['lateOutLimit'] ?? json['late_out_limit'] ?? 15) as int,
      earlyInLimit: (json['earlyInLimit'] ?? json['early_in_limit'] ?? 15) as int,
      earlyOutLimit: (json['earlyOutLimit'] ?? json['early_out_limit'] ?? 15) as int,
      isActive: (json['isActive'] ?? json['is_active'] ?? true) == true || (json['isActive'] ?? json['is_active'] ?? 1) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'lateInLimit': lateInLimit,
      'lateOutLimit': lateOutLimit,
      'earlyInLimit': earlyInLimit,
      'earlyOutLimit': earlyOutLimit,
      'isActive': isActive,
    };
  }
}
