class HolidayException {
  final int id;
  final int holidayId;
  final int? teamId;
  final int? userId;
  final String? teamName;
  final String? userName;
  final String? note;

  HolidayException({
    required this.id,
    required this.holidayId,
    this.teamId,
    this.userId,
    this.teamName,
    this.userName,
    this.note,
  });

  factory HolidayException.fromJson(Map<String, dynamic> json) {
    return HolidayException(
      id: json['id'],
      holidayId: json['holidayId'] ?? json['holiday_id'],
      teamId: json['teamId'] ?? json['team_id'],
      userId: json['userId'] ?? json['user_id'],
      teamName: json['team']?['name'],
      userName: json['user']?['name'],
      note: json['note'],
    );
  }
}

class Holiday {
  final int id;
  final int companyId;
  final String date; // YYYY-MM-DD
  final String name;
  final bool isActive;
  final List<HolidayException> exceptions;

  Holiday({
    required this.id,
    required this.companyId,
    required this.date,
    required this.name,
    this.isActive = true,
    this.exceptions = const [],
  });

  DateTime get dateTime => DateTime.parse(date);

  factory Holiday.fromJson(Map<String, dynamic> json) {
    final exList = (json['exceptions'] as List<dynamic>?)
        ?.map((e) => HolidayException.fromJson(e))
        .toList() ?? [];

    return Holiday(
      id: json['id'],
      companyId: json['companyId'] ?? json['company_id'],
      date: json['date'],
      name: json['name'] ?? 'Company Holiday',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      exceptions: exList,
    );
  }
}
