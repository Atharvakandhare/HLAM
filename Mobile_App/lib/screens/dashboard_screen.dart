import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../models/attendance.dart';
import '../models/shift.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/reminder_alarm_service.dart';
import 'attendance_capture_screen.dart';
import 'view_face_registration_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_marketing_tracking_screen.dart';
import 'team_management_screen.dart';
import 'manager_team_screen.dart';
import 'company_holidays_screen.dart';
import 'main_navigation_screen.dart';
import 'register_company_screen.dart';
import '../utils/app_messages.dart';
import '../widgets/app_avatar.dart';
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  String _currentTime = '';
  String _currentDate = '';
  User? _user;
  bool _isFirstLoad = true;
  bool _is24HourFormat = false;

  void _toggleTimeFormat() {
    setState(() {
      _is24HourFormat = !_is24HourFormat;
    });
    _updateTime();
  }

  // Timers for Alarms
  Timer? _alarmTimer;
  bool _isAlarmShowing = false;
  Timer? _alarmAutoCloseTimer;

  // Calendar summary navigation state
  int _calendarMonth = DateTime.now().month;
  int _calendarYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );

    _startAlarmLoop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRefresh();
    });
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    final user = await AuthService().getUser();
    if (mounted) {
      setState(() {
        _user = user;
      });
    }

    // Fetch employees for both birthday card check and admin view
    await provider.fetchEmployees();

    // Fetch company admin's profile picture as company logo
    await provider.fetchCompanyLogo();

    // Always fetch holidays for calendar display
    if (user?.companyId != null) {
      provider.fetchHolidays(year: _calendarYear);
    }

    if (user != null) {
      if (user.role == 'system_admin' || user.role == 'company_admin') {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await Future.wait([
          provider.fetchStats(startDate: todayStr, endDate: todayStr),
          provider.fetchTeams(),
        ]);
      } else {
        await Future.wait([
          provider.fetchTodayAttendance(),
          provider.fetchMyAttendance(
            month: _calendarMonth,
            year: _calendarYear,
            showLoading: false,
          ),
          provider.fetchMyLeaves(),
          provider.fetchUserStats(),
        ]);

        try {
          final hasCheckedIn = provider.todayAttendance != null;
          final hasCheckedOut = provider.todayAttendance?.checkOutTime != null;
          await ReminderAlarmService.scheduleAlarms(
            user,
            hasCheckedIn: hasCheckedIn,
            hasCheckedOut: hasCheckedOut,
          );
        } catch (alarmError) {
          debugPrint("Failed to schedule alarms: $alarmError");
        }
      }
    }

    if (mounted) {
      setState(() {
        _isFirstLoad = false;
      });
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = _is24HourFormat
            ? DateFormat('HH:mm:ss').format(now)
            : DateFormat('hh:mm:ss a').format(now);
        _currentDate = DateFormat('EEEE, dd MMM yyyy').format(now);
      });
    }
  }

  void _startAlarmLoop() {
    // Check every 30 seconds for higher precision matching
    _alarmTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAlarms();
    });
  }

  void _checkAlarms() async {
    final user = _user;
    if (user == null || _isAlarmShowing) return;

    final provider = Provider.of<AppProvider>(context, listen: false);

    // Only alert for employees, managers, TLs (not company admins or system admins)
    if (_isAdmin) return;

    final now = DateTime.now();
    final String currentHHMM = DateFormat('HH:mm').format(now);
    final String todayStr = DateFormat('yyyy-MM-dd').format(now);

    final String? schedInStr = user.companyCheckInTime; // "09:00:00"
    final String? schedOutStr = user.companyCheckOutTime; // "18:00:00"

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastInAlarm = prefs.getString('lastCheckInAlarmDate');
      final String? lastOutAlarm = prefs.getString('lastCheckOutAlarmDate');

      if (schedInStr != null && schedInStr.length >= 5) {
        final String inHHMM = schedInStr.substring(0, 5);
        final bool hasNotCheckedIn = provider.todayAttendance == null;

        // Trigger alarm if current time is at or past scheduled time, employee hasn't checked in, and alarm hasn't fired today
        if (currentHHMM.compareTo(inHHMM) >= 0 &&
            hasNotCheckedIn &&
            lastInAlarm != todayStr) {
          await prefs.setString('lastCheckInAlarmDate', todayStr);
          _triggerAlarm("Reminder!!! Please Check-In, according to the time.");
          return;
        }
      }

      if (schedOutStr != null && schedOutStr.length >= 5) {
        final String outHHMM = schedOutStr.substring(0, 5);
        final bool hasNotCheckedOut =
            provider.todayAttendance != null &&
            provider.todayAttendance!.checkOutTime == null;

        // Trigger alarm if current time is at or past scheduled time, employee checked in but hasn't checked out, and alarm hasn't fired today
        if (currentHHMM.compareTo(outHHMM) >= 0 &&
            hasNotCheckedOut &&
            lastOutAlarm != todayStr) {
          await prefs.setString('lastCheckOutAlarmDate', todayStr);
          _triggerAlarm("Reminder!!! Please Check-Out, according to the time.");
          return;
        }
      }
    } catch (e) {
      debugPrint("Error in checkAlarms: $e");
    }
  }

  void _triggerAlarm(String message) {
    if (!mounted) return;
    setState(() {
      _isAlarmShowing = true;
    });

    try {
      ReminderAlarmService.triggerImmediateAlarm("Attendance Alert", message);
    } catch (e) {
      debugPrint("Failed to trigger immediate alarm: $e");
    }

    _alarmAutoCloseTimer?.cancel();
    _alarmAutoCloseTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _isAlarmShowing) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false, // Prevent physical back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFEF4444), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () {
                          _alarmAutoCloseTimer?.cancel();
                          setState(() {
                            _isAlarmShowing = false;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ATTENDANCE ALERT',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      _alarmAutoCloseTimer?.cancel();
                      setState(() {
                        _isAlarmShowing = false;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(200, 52),
                    ),
                    child: const Text(
                      'Dismiss Reminder',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isAlarmShowing = false;
      ReminderAlarmService.cancelActiveReminders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alarmTimer?.cancel();
    _alarmAutoCloseTimer?.cancel();
    super.dispose();
  }

  bool get _isAdmin =>
      _user?.role == 'system_admin' || _user?.role == 'company_admin';

  Widget _buildDigitalIDCard() {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    final profileUrl =
        user.profilePicture != null && user.profilePicture!.isNotEmpty
        ? '${ApiService.baseUrl.replaceAll('/api', '')}${user.profilePicture}'
        : null;

    final companyLogo = Provider.of<AppProvider>(context).companyLogoUrl;
    final logoUrl = companyLogo != null && companyLogo.isNotEmpty
        ? '${ApiService.baseUrl.replaceAll('/api', '')}$companyLogo'
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(
                Icons.fingerprint_rounded,
                size: 180,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            Positioned(
              left: -40,
              top: -40,
              child: Icon(
                Icons.verified_user_rounded,
                size: 130,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (logoUrl != null) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  image: DecorationImage(
                                    image: NetworkImage(logoUrl),
                                    fit: BoxFit.cover,
                                    onError: (exception, stackTrace) {
                                      debugPrint('Error loading company logo: $exception');
                                    },
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                (user.companyName ?? 'HIRELYFT INDIA PVT. LTD.')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF10B981),
                              size: 11,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.15),
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildIDDetailRow(
                                    'EMPLOYEE ID',
                                    user.employeeId ?? '—',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildIDDetailRow(
                                    'DEPARTMENT',
                                    user.department ?? '—',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildIDDetailRow('EMAIL', user.email),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          SwitchTabNotification(
                            _isAdmin ? 2 : 3,
                          ).dispatch(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AppAvatar(
                            radius: 36,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            imageUrl: profileUrl,
                            fallback: const Icon(
                              Icons.person_rounded,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIDDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMinimalistTimeAndDate() {
    return AnimatedGradientBorder(
      borderWidth: 2.0,
      borderRadius: 20.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF2563EB),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentDate.contains(', ')
                        ? _currentDate.split(', ').last
                        : _currentDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 12H/24H switcher
                  GestureDetector(
                    onTap: _toggleTimeFormat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        _is24HourFormat ? '24H' : '12H',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== BIRTHDAY CARD ==========
  Widget _buildBirthdayCard(List<User> employees) {
    final now = DateTime.now();
    final List<User> birthdayColleagues = [];

    for (var emp in employees) {
      if (emp.dob != null) {
        try {
          final dob = DateTime.parse(emp.dob!);
          if (dob.month == now.month && dob.day == now.day) {
            birthdayColleagues.add(emp);
          }
        } catch (_) {}
      }
    }

    if (birthdayColleagues.isEmpty) return const SizedBox.shrink();

    return BirthdayCelebrationCard(colleagues: birthdayColleagues);
  }

  // ========== CALENDAR VIEW ==========
  Widget _buildCalendarView(AppProvider provider) {
    final now = DateTime.now();
    final daysInMonth = DateTime(_calendarYear, _calendarMonth + 1, 0).day;
    final firstWeekday = DateTime(
      _calendarYear,
      _calendarMonth,
      1,
    ).weekday; // 1 = Mon, 7 = Sun
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                onPressed: () {
                  setState(() {
                    _calendarMonth--;
                    if (_calendarMonth < 1) {
                      _calendarMonth = 12;
                      _calendarYear--;
                    }
                    provider.fetchMyAttendance(
                      month: _calendarMonth,
                      year: _calendarYear,
                      showLoading: false,
                    );
                    provider.fetchHolidays(year: _calendarYear);
                    provider.fetchMyLeaves();
                  });
                },
              ),
              Text(
                DateFormat(
                  'MMMM yyyy',
                ).format(DateTime(_calendarYear, _calendarMonth)),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                onPressed: () {
                  setState(() {
                    _calendarMonth++;
                    if (_calendarMonth > 12) {
                      _calendarMonth = 1;
                      _calendarYear++;
                    }
                    provider.fetchMyAttendance(
                      month: _calendarMonth,
                      year: _calendarYear,
                      showLoading: false,
                    );
                    provider.fetchHolidays(year: _calendarYear);
                    provider.fetchMyLeaves();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color.fromARGB(255, 10, 10, 10),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + startOffset,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final day = index - startOffset + 1;
              final cellDate = DateTime(_calendarYear, _calendarMonth, day);
              final isWeekend =
                  cellDate.weekday == DateTime.saturday ||
                  cellDate.weekday == DateTime.sunday;
              final isToday =
                  now.year == _calendarYear &&
                  now.month == _calendarMonth &&
                  now.day == day;

              // Check holiday
              final holiday = provider.getHolidayForDate(cellDate);
              final isHoliday = holiday != null;

              // Check approved leave for this day
              final cellDateStr = DateFormat('yyyy-MM-dd').format(cellDate);
              final approvedLeave = provider.leaves
                  .cast<Map<String, dynamic>?>()
                  .firstWhere((l) {
                    if (l == null) return false;
                    final status = (l['status'] ?? '').toString().toLowerCase();
                    if (status != 'approved') return false;
                    final start = l['startDate']?.toString() ?? '';
                    final end = l['endDate']?.toString() ?? '';
                    return cellDateStr.compareTo(start) >= 0 &&
                        cellDateStr.compareTo(end) <= 0;
                  }, orElse: () => null);
              final isOnLeave = approvedLeave != null;

              final record = provider.attendance.firstWhere(
                (a) {
                  try {
                    final d = DateTime.parse(a.date);
                    return d.year == _calendarYear &&
                        d.month == _calendarMonth &&
                        d.day == day;
                  } catch (_) {
                    return false;
                  }
                },
                orElse: () => Attendance(
                  id: -1,
                  userId: -1,
                  date: '',
                  selfieUrl: '',
                  status: 'absent',
                ),
              );

              Color cellColor = Colors.grey.shade50;
              Color textColor = const Color(0xFF1E293B);
              Border? cellBorder;
              Widget? overlay;

              if (isToday) {
                cellBorder = Border.all(
                  color: const Color(0xFF2563EB),
                  width: 1.5,
                );
              }

              // Priority: holiday > leave > attendance record > default
              if (isHoliday) {
                cellColor = const Color(0xFFF97316).withValues(alpha: 0.15);
                textColor = const Color(0xFFF97316);
                overlay = const Positioned(
                  bottom: 1,
                  right: 1,
                  child: Text('🏖', style: TextStyle(fontSize: 7)),
                );
              } else if (isOnLeave) {
                // Approved leave — purple with 📋 icon
                cellColor = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
                textColor = const Color(0xFF8B5CF6);
                overlay = const Positioned(
                  bottom: 1,
                  right: 1,
                  child: Text('📋', style: TextStyle(fontSize: 7)),
                );
              } else if (record.id != -1) {
                if (record.status == 'half_day') {
                  cellColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                  textColor = const Color(0xFFF59E0B);
                } else if (record.status == 'present' ||
                    record.status == 'late') {
                  cellColor = const Color(0xFF10B981).withValues(alpha: 0.15);
                  textColor = const Color(0xFF10B981);
                } else if (record.status == 'absent') {
                  cellColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
                  textColor = const Color(0xFFEF4444);
                } else {
                  if (record.checkOutTime != null) {
                    cellColor = const Color(0xFF10B981).withValues(alpha: 0.15);
                    textColor = const Color(0xFF10B981);
                  } else {
                    cellColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                    textColor = const Color(0xFFF59E0B);
                  }
                }
              } else {
                if (isWeekend) {
                  cellColor = const Color.fromARGB(
                    255,
                    150,
                    150,
                    150,
                  ).withValues(alpha: 0.3);
                  textColor = Colors.grey.shade500;
                } else if (cellDate.isBefore(now)) {
                  cellColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
                  textColor = const Color(0xFFEF4444);
                }
              }

              Widget cell = Container(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(10),
                  border: cellBorder,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (overlay != null) overlay,
                  ],
                ),
              );

              // Tooltip for holidays
              if (isHoliday) {
                cell = Tooltip(message: holiday.name, child: cell);
              } else if (isOnLeave) {
                final leaveReason =
                    approvedLeave['reason']?.toString() ?? 'Approved Leave';
                cell = Tooltip(
                  message: '📋 On Leave: $leaveReason',
                  child: cell,
                );
              }

              return cell;
            },
          ),
          const SizedBox(height: 16),
          const Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'Present',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFFF59E0B)),
                  SizedBox(width: 4),
                  Text(
                    'Half Day',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFFEF4444)),
                  SizedBox(width: 4),
                  Text(
                    'Absent',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFFF97316)),
                  SizedBox(width: 4),
                  Text(
                    'Holiday 🏖',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF8B5CF6)),
                  SizedBox(width: 4),
                  Text(
                    'On Leave 📋',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    if (_user == null || (_isFirstLoad && provider.isLoading)) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF2563EB),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingHeader(),
                const SizedBox(height: 24),

                // Colleague Birthdays Card
                _buildBirthdayCard(provider.employees),

                if (_isAdmin)
                  _buildTimeCard()
                else ...[
                  _buildDigitalIDCard(),
                  const SizedBox(height: 16),
                  _buildMinimalistTimeAndDate(),
                ],
                const SizedBox(height: 24),
                if (_isAdmin)
                  ..._buildAdminContent(provider)
                else
                  ..._buildEmployeeContent(provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            SwitchTabNotification(_isAdmin ? 2 : 3).dispatch(context);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppAvatar(
              radius: 26,
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              imageUrl: _user?.profilePicture != null &&
                      _user!.profilePicture!.isNotEmpty
                  ? '${ApiService.baseUrl.replaceAll('/api', '')}${_user!.profilePicture}'
                  : null,
              fallback: const Icon(
                Icons.person_rounded,
                color: Color(0xFF2563EB),
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${_user?.name ?? 'User'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isAdmin
                    ? 'Administrator'
                    : (_user?.department ?? 'Department'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_isAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
      ],
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left side: Digital Clock
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 24),

            // Right side: Date Pill & 12H/24H Switcher side-by-side
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Color(0xFF64748B),
                        size: 11,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _currentDate.contains(', ')
                            ? _currentDate.split(', ').last
                            : _currentDate,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 12H/24H switcher
                GestureDetector(
                  onTap: _toggleTimeFormat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _is24HourFormat ? '24H' : '12H',
                      style: const TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== ADMIN CONTENT ==========
  List<Widget> _buildAdminContent(AppProvider provider) {
    final stats = provider.attendanceStats;
    final employees = provider.employees;
    final teamsCount = provider.teams.length;

    return [
      const Row(
        children: [
          Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      
      // Combined Stats Card: Employees Count & Teams Count
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Employees section
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/employees'),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  const Color(0xFF2563EB).withValues(alpha: 0.03),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.people_alt_rounded,
                              color: Color(0xFF2563EB),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${employees.length}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Employees',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Vertical divider line (floating in the middle)
                Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  color: const Color(0xFFE2E8F0),
                ),
                // Teams section
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                  const Color(0xFF8B5CF6).withValues(alpha: 0.03),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$teamsCount',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Total Teams',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Redesigned grid action cards
      Row(
        children: [
          _buildGridAdminActionCard(
            'Add Employee',
            'Register new staff',
            Icons.person_add_alt_1_rounded,
            const Color(0xFF10B981),
            () => Navigator.pushNamed(context, '/add_employee'),
          ),
          const SizedBox(width: 12),
          _buildGridAdminActionCard(
            'Leave Requests',
            'Review leave apps',
            Icons.edit_document,
            const Color(0xFFF59E0B),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLeavesScreen()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _buildGridAdminActionCard(
            'Manage Teams',
            'Setup & assign',
            Icons.groups_rounded,
            const Color(0xFF8B5CF6),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildGridAdminActionCard(
            'Marketing Live Track',
            'Monitor movements',
            Icons.map_rounded,
            const Color(0xFF2563EB),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminMarketingTrackingScreen(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_user?.role == 'system_admin') ...[
        Row(
          children: [
            _buildGridAdminActionCard(
              'Company Holidays',
              'Set holidays 🏖',
              Icons.beach_access_rounded,
              const Color(0xFFF97316),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompanyHolidaysScreen(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildGridAdminActionCard(
              'Register Company',
              'Create new accounts',
              Icons.domain_add_rounded,
              const Color(0xFF7C3AED),
              () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterCompanyScreen(),
                  ),
                );
                if (result == true && mounted) {
                  AppMessages.showSuccess(
                    context,
                    'Company registered successfully!',
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFullWidthAdminActionCard(
          'Company Registrations',
          'Manage, approve, or reject company self-registration requests',
          Icons.domain_verification_rounded,
          const Color(0xFF10B981),
          () {
            Navigator.pushNamed(context, '/company_registrations');
          },
        ),
      ] else ...[
        _buildFullWidthAdminActionCard(
          'Company Holidays 🏖',
          'Set, manage and upload company holiday sheets',
          Icons.beach_access_rounded,
          const Color(0xFFF97316),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CompanyHolidaysScreen(),
            ),
          ),
        ),
      ],

      const SizedBox(height: 28),
      const Row(
        children: [
          Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5)),
          SizedBox(width: 8),
          Text(
            'Today\'s Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          _buildStatItem(
            'Total',
            stats['totalUsers']?.toString() ?? '0',
            const Color(0xFF2563EB),
            Icons.groups_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'Present',
            ((stats['totalPresent'] ?? 0) + (stats['totalLate'] ?? 0))
                .toString(),
            const Color(0xFF10B981),
            Icons.check_circle_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'Absent',
            (stats['totalAbsent'] ?? 0).toString(),
            const Color(0xFFEF4444),
            Icons.cancel_rounded,
          ),
        ],
      ),
      const SizedBox(height: 28),
      const Row(
        children: [
          Icon(Icons.recent_actors_rounded, color: Color(0xFF0EA5E9)),
          SizedBox(width: 8),
          Text(
            'Recent Employees',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (employees.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('No employees yet', style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
      else
        ...employees.take(5).map((emp) => _buildEmployeeCard(emp)),
    ];
  }

  Widget _buildAdminActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthAdminActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridAdminActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoodEnergyPicker(BuildContext context) {
    String? selectedMood;
    String? selectedEnergy;
    int? selectedShiftId;

    final moods = [
      {'key': 'happy', 'emoji': '😊', 'label': 'Happy'},
      {'key': 'sad', 'emoji': '😢', 'label': 'Sad'},
      {'key': 'exhausted', 'emoji': '😩', 'label': 'Exhausted'},
      {'key': 'angry', 'emoji': '😤', 'label': 'Angry'},
    ];

    final energies = [
      {'key': 'low', 'emoji': '🔋', 'label': 'Low'},
      {'key': 'medium', 'emoji': '🔋🔋', 'label': 'Medium'},
      {'key': 'high', 'emoji': '🔋🔋🔋', 'label': 'High'},
    ];

    final provider = Provider.of<AppProvider>(context, listen: false);
    final isFirstCheckIn = provider.todayAttendance == null;
    if (isFirstCheckIn) {
      provider.fetchShifts();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final provider = Provider.of<AppProvider>(ctx);
          
          if (isFirstCheckIn && selectedShiftId == null) {
            if (_user?.defaultShiftId != null &&
                provider.shifts.any((s) => s.id == _user?.defaultShiftId)) {
              selectedShiftId = _user?.defaultShiftId;
            } else {
              selectedShiftId = 0;
            }
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
              top: 0,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'How are you feeling today? 🌟',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFirstCheckIn 
                      ? 'Select your shift, mood, and energy level before checking in.'
                      : 'Select your mood and energy level before checking in (both required)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  
                  if (isFirstCheckIn) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Select Today\'s Shift',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (provider.isLoading && provider.shifts.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (provider.shifts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No active shifts configured. Default company office hours will apply.',
                                style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: selectedShiftId,
                            isExpanded: true,
                            hint: const Text('Select a Shift'),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4F46E5)),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: 0,
                                child: Text(
                                  'None Shift Assigned (Standard Office Hours)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              ...provider.shifts.map((Shift shift) {
                                return DropdownMenuItem<int?>(
                                  value: shift.id,
                                  child: Text(
                                    '${shift.name} (${shift.checkInTime.substring(0, 5)} - ${shift.checkOutTime.substring(0, 5)})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (int? value) {
                              setSheetState(() {
                                selectedShiftId = value;
                              });
                            },
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Mood',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: moods.map((m) {
                      final isSelected = selectedMood == m['key'];
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedMood = m['key']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 74,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4F46E5)
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                m['emoji']!,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['label']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Energy Level',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: energies.map((e) {
                      final isSelected = selectedEnergy == e['key'];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedEnergy = e['key']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    e['emoji']!,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e['label']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isFirstCheckIn && provider.shifts.isNotEmpty && selectedShiftId == null) {
                          AppMessages.showError(
                            context,
                            'Please select a shift to proceed with check-in.',
                          );
                          return;
                        }
                        if (selectedMood == null) {
                          AppMessages.showError(
                            context,
                            'Please select your mood to proceed with check-in.',
                          );
                          return;
                        }
                        if (selectedEnergy == null) {
                          AppMessages.showError(
                            context,
                            'Please select your energy level to proceed with check-in.',
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceCaptureScreen(
                              isCheckout: false,
                              mood: selectedMood,
                              energyLevel: selectedEnergy,
                              shiftId: selectedShiftId,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue to Check-In →',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCheckoutReasonDialog(BuildContext context, int attendanceId) {
    String? selectedReason = "Today's Work Done/Login Off";
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showTextField = selectedReason == "Other";
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Checkout Reason',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please select your reason for checking out:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "Today's Work Done/Login Off",
                        child: Text(
                          "Today's Work Done/Login Off",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "Personal Reason",
                        child: Text(
                          "Personal Reason",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "Half Day",
                        child: Text("Half Day", style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: "Other",
                        child: Text("Other", style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedReason = val;
                      });
                    },
                  ),
                  if (showTextField) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Please specify your custom reason:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Enter custom reason...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final String finalReason;
                  if (selectedReason == "Other") {
                    finalReason = reasonController.text.trim();
                    if (finalReason.isEmpty) {
                      AppMessages.showError(
                        context,
                        'Please specify your custom reason.',
                      );
                      return;
                    }
                  } else {
                    finalReason = selectedReason!;
                  }

                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendanceCaptureScreen(
                        isCheckout: true,
                        checkoutReason: finalReason,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmployeeCard(User emp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(
                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.domain_rounded,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      emp.department ?? emp.email,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: emp.isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  emp.isActive
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 12,
                  color: emp.isActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  emp.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: emp.isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerFaceProcess() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isFirstLoad = true;
      });

      final authService = AuthService();
      final response = await authService.registerFace(image);

      await _handleRefresh();

      if (mounted) {
        AppMessages.showSuccess(
          context,
          response['message'] ?? 'Face registered successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
    }
  }

  Widget _buildFaceRegistrationCard() {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    final isRegistered = user.isFaceRegistered == true;

    if (isRegistered) {
      return GestureDetector(
        onTap: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewFaceRegistrationScreen(user: user),
            ),
          );
          if (refresh == true) {
            _handleRefresh();
          }
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF10B981),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Face Verification',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Biometric signature matched. Tap to view details.',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF047857),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFFDA4AF).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.face_unlock_rounded,
                      color: Color(0xFFE11D48),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Biometric Registration',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF9F1239),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'REQUIRED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Register reference profile photo to unlock check-in.',
                          style: TextStyle(
                            color: Color(0xFFBE123C),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _registerFaceProcess,
                  icon: const Icon(Icons.camera_front_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Register Face Descriptor',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ========== EMPLOYEE CONTENT ==========
  List<Widget> _buildEmployeeContent(AppProvider provider) {
    final stats = provider.userStats;
    final today = provider.todayAttendance;

    final bool isCheckedIn = today != null && today.checkOutTime == null;
    final bool isCheckedOut = today != null && today.checkOutTime != null;

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TODAY\'S ATTENDANCE',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Color(0xFF64748B),
              letterSpacing: 1.0,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (isCheckedIn
                          ? const Color(0xFF10B981)
                          : isCheckedOut
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF64748B))
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isCheckedIn
                  ? 'Checked In: ${DateFormat('hh:mm a').format(today.checkInTime!)}'
                  : isCheckedOut
                  ? 'Checked Out: ${DateFormat('hh:mm a').format(today.checkOutTime!)}'
                  : 'Pending Check-in',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: isCheckedIn
                    ? const Color(0xFF10B981)
                    : isCheckedOut
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (!isCheckedIn)
        PremiumSlideButton(
          text: 'Slide right to Check-in',
          icon: Icons.arrow_forward_rounded,
          color: const Color(0xFF10B981),
          isSlideLeft: false,
          onTrigger: () {
            _showMoodEnergyPicker(context);
          },
        )
      else
        PremiumSlideButton(
          text: 'Slide left to Check-out',
          icon: Icons.arrow_back_rounded,
          color: const Color(0xFFEF4444),
          isSlideLeft: true,
          onTrigger: () {
            _showCheckoutReasonDialog(context, today.id);
          },
        ),
      const SizedBox(height: 24),
      _buildFaceRegistrationCard(),
      const SizedBox(height: 28),
      if (_user?.role == 'manager' || _user?.role == 'team_leader') ...[
        _buildFullWidthAdminActionCard(
          'Manage My Team',
          'Manage members, view attendance, review leave applications',
          Icons.groups_rounded,
          const Color(0xFF8B5CF6),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ManagerTeamScreen()),
          ),
        ),
        const SizedBox(height: 28),
      ],
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    const Color(0xFFF59E0B).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.timer_rounded,
                color: Color(0xFFF59E0B),
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Working Hours',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today?.workingHours ?? '00:00:00',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),

      // Mini Grid Calendar Card replaces the old flat stat view!
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Monthly Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'Exclude Sat/Sun',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: provider.excludeWeekends,
                    activeThumbColor: const Color(0xFF2563EB),
                    activeTrackColor: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: 0.5),
                    onChanged: (val) {
                      provider.excludeWeekends = val;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Monthly Summary Calendar Grid Card
      _buildCalendarView(provider),

      const SizedBox(height: 20),
      Row(
        children: [
          _buildStatItem(
            'Present',
            stats['present']?.toString() ?? '0',
            const Color(0xFF10B981),
            Icons.check_circle_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'Absents',
            stats['absents']?.toString() ?? '0',
            const Color(0xFFEF4444),
            Icons.cancel_rounded,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _buildStatItem(
            'Half Day',
            stats['halfDay']?.toString() ?? '0',
            const Color(0xFFF59E0B),
            Icons.timelapse_rounded,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'On Leave',
            stats['leaves']?.toString() ?? '0',
            const Color(0xFF8B5CF6),
            Icons.event_busy_rounded,
          ),
        ],
      ),
    ];
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== FLOATING CELEBRATION EMOJI ==========
class FloatingCelebrationEmoji extends StatefulWidget {
  final String emoji;
  final double size;
  final Duration duration;
  final double startX;
  final double startY;
  final double driftX;
  final double driftY;

  const FloatingCelebrationEmoji({
    super.key,
    required this.emoji,
    required this.size,
    required this.duration,
    required this.startX,
    required this.startY,
    required this.driftX,
    required this.driftY,
  });

  @override
  State<FloatingCelebrationEmoji> createState() =>
      _FloatingCelebrationEmojiState();
}

class _FloatingCelebrationEmojiState extends State<FloatingCelebrationEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dxAnimation;
  late Animation<double> _dyAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _dxAnimation = Tween<double>(
      begin: widget.startX,
      end: widget.startX + widget.driftX,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _dyAnimation = Tween<double>(
      begin: widget.startY,
      end: widget.startY + widget.driftY,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotateAnimation = Tween<double>(
      begin: -0.2,
      end: 0.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _dxAnimation.value,
          top: _dyAnimation.value,
          child: Transform.rotate(
            angle: _rotateAnimation.value,
            child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
          ),
        );
      },
    );
  }
}

// ========== CELEBRATION CARD ==========
class BirthdayCelebrationCard extends StatefulWidget {
  final List<User> colleagues;
  const BirthdayCelebrationCard({super.key, required this.colleagues});

  @override
  State<BirthdayCelebrationCard> createState() =>
      _BirthdayCelebrationCardState();
}

class _BirthdayCelebrationCardState extends State<BirthdayCelebrationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.colleagues.isEmpty) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFF43F5E), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Floating Animated background particles/emojis
              const FloatingCelebrationEmoji(
                emoji: '🎈',
                size: 16,
                duration: Duration(seconds: 4),
                startX: 12,
                startY: 8,
                driftX: 8,
                driftY: -10,
              ),
              const FloatingCelebrationEmoji(
                emoji: '🎉',
                size: 14,
                duration: Duration(seconds: 5),
                startX: 270,
                startY: 10,
                driftX: -10,
                driftY: 8,
              ),
              const FloatingCelebrationEmoji(
                emoji: '🥳',
                size: 15,
                duration: Duration(seconds: 3),
                startX: 30,
                startY: 42,
                driftX: 10,
                driftY: -8,
              ),
              const FloatingCelebrationEmoji(
                emoji: '✨',
                size: 12,
                duration: Duration(seconds: 6),
                startX: 240,
                startY: 38,
                driftX: -8,
                driftY: -10,
              ),
              const FloatingCelebrationEmoji(
                emoji: '🎁',
                size: 13,
                duration: Duration(seconds: 4),
                startX: 140,
                startY: 5,
                driftX: 8,
                driftY: 8,
              ),

              // Glowing Glassmorphic Overlay Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Birthday Icon container
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text('🎂', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    // Wishing Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'HAPPY BIRTHDAY!',
                                style: TextStyle(
                                  color: Color(0xFFFDE047), // Gold accent
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('✨', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...widget.colleagues.map((colleague) {
                            final String dept =
                                colleague.department ??
                                colleague.teamName ??
                                'Team Member';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 1.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  children: [
                                    TextSpan(text: colleague.name),
                                    TextSpan(
                                      text: ' ($dept)',
                                      style: TextStyle(
                                        color: Colors.yellow.shade100,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                          const Text(
                            'Wishing you a fantastic day ahead!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Swinging Celebration Emoji on the Right
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final double angle =
                            sin(_pulseController.value * 2 * pi) * 0.12;
                        return Transform.rotate(
                          angle: angle,
                          child: const Text(
                            '🥳',
                            style: TextStyle(fontSize: 28),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumSlideButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool isSlideLeft;
  final VoidCallback onTrigger;

  const PremiumSlideButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.isSlideLeft,
    required this.onTrigger,
  });

  @override
  State<PremiumSlideButton> createState() => _PremiumSlideButtonState();
}

class _PremiumSlideButtonState extends State<PremiumSlideButton>
    with TickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _controller;
  late Animation<double> _animation;
  AnimationController? _shimmerController;
  int _lastHapticTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _shimmerController ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        const double buttonSize = 56.0;
        final double maxDragOffset = totalWidth - buttonSize - 8.0;
        final double progress = (_dragOffset.abs() / maxDragOffset).clamp(
          0.0,
          1.0,
        );

        final double shadowBlur = 18.0 + (progress * 12.0);
        final double shadowSpread = progress * 2.0;

        return AnimatedBuilder(
          animation: _shimmerController!,
          builder: (context, child) {
            return Container(
              width: totalWidth,
              height: 66,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: 0.35 + (progress * 0.15),
                    ),
                    blurRadius: shadowBlur,
                    spreadRadius: shadowSpread,
                    offset: Offset(0, 8 + (progress * 4)),
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    Colors.white.withValues(alpha: 0.32),
                    widget.color,
                  ],
                  stops: const [0.35, 0.5, 0.65],
                  begin: Alignment(
                    -2.0 + (_shimmerController!.value * 4.0),
                    -1.0,
                  ),
                  end: Alignment(-1.0 + (_shimmerController!.value * 4.0), 1.0),
                ),
              ),
              child: child,
            );
          },
          child: Stack(
            alignment: widget.isSlideLeft
                ? Alignment.centerRight
                : Alignment.centerLeft,
            children: [
              Positioned(
                left: widget.isSlideLeft ? null : 0,
                right: widget.isSlideLeft ? 0 : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: widget.isSlideLeft
                      ? (_dragOffset.abs() + buttonSize + 8.0)
                      : (_dragOffset + buttonSize + 8.0),
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.12 + (progress * 0.08),
                    ),
                    borderRadius: BorderRadius.circular(29),
                  ),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  opacity: (1.0 - (progress * 2.0)).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!widget.isSlideLeft) ...[
                        _buildShimmerArrow(
                          widget.color,
                          isLeft: false,
                          dragProgress: progress,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.text.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.8,
                        ),
                      ),
                      if (widget.isSlideLeft) ...[
                        const SizedBox(width: 10),
                        _buildShimmerArrow(
                          widget.color,
                          isLeft: true,
                          dragProgress: progress,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                left: widget.isSlideLeft ? null : _dragOffset,
                right: widget.isSlideLeft ? _dragOffset.abs() : null,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      if (widget.isSlideLeft) {
                        _dragOffset += details.primaryDelta!;
                        if (_dragOffset > 0) _dragOffset = 0;
                        if (_dragOffset.abs() > maxDragOffset) {
                          _dragOffset = -maxDragOffset;
                        }
                      } else {
                        _dragOffset += details.primaryDelta!;
                        if (_dragOffset < 0) _dragOffset = 0;
                        if (_dragOffset > maxDragOffset) {
                          _dragOffset = maxDragOffset;
                        }
                      }

                      final double currentProgress =
                          _dragOffset.abs() / maxDragOffset;
                      final int tick = (currentProgress * 10).floor();
                      if (tick != _lastHapticTick) {
                        HapticFeedback.lightImpact();
                        _lastHapticTick = tick;
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    final double currentProgress =
                        _dragOffset.abs() / maxDragOffset;
                    if (currentProgress >= 0.8) {
                      HapticFeedback.mediumImpact();
                      widget.onTrigger();
                      setState(() {
                        _dragOffset = 0.0;
                        _lastHapticTick = 0;
                      });
                    } else {
                      final double startOffset = _dragOffset;
                      _controller.reset();
                      _animation.addListener(() {
                        setState(() {
                          _dragOffset = startOffset * _animation.value;
                        });
                      });
                      _controller.forward();
                    }
                  },
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.2 + (progress * 0.08),
                          ),
                          blurRadius: 10 + (progress * 4),
                          offset: Offset(0, 4 + (progress * 2)),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: (_dragOffset / maxDragOffset) * 0.8,
                        child: Icon(widget.icon, color: widget.color, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerArrow(
    Color color, {
    required bool isLeft,
    required double dragProgress,
  }) {
    final double finalOpacity = (1.0 - (dragProgress * 2.0)).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Icon(
          isLeft
              ? Icons.keyboard_double_arrow_left_rounded
              : Icons.keyboard_double_arrow_right_rounded,
          color: Colors.white.withValues(
            alpha: (0.3 + (0.7 * value)) * finalOpacity,
          ),
          size: 18,
        );
      },
    );
  }
}

class AnimatedGradientBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final List<Color> gradientColors;
  final Duration duration;

  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.borderWidth = 2.0,
    this.borderRadius = 20.0,
    this.gradientColors = const [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFF6366F1),
    ],
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: widget.gradientColors,
              transform: GradientRotation(
                _controller.value * 2 * 3.141592653589793,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.borderWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                widget.borderRadius - widget.borderWidth,
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
