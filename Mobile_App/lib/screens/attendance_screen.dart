import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/attendance.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/holiday.dart';
import '../utils/file_saver.dart';
import 'attendance_details_screen.dart';

// ─── Color Constants ──────────────────────────────────────────────────────────
const Color kPresent  = Color(0xFF10B981); // green
const Color kAbsent   = Color(0xFFEF4444); // red
const Color kLeave    = Color(0xFF7C3AED); // purple
const Color kHalfDay  = Color(0xFFF97316); // orange
const Color kHoliday  = Color(0xFF78350F); // brown
const Color kWeekend  = Color(0xFF94A3B8); // slate
const Color kCheckedIn = Color(0xFF2563EB); // royal blue

// ─── Grouped Attendance Helper Model ─────────────────────────────────────────
class GroupedAttendance {
  final String dateString;
  final List<Attendance> sessions;

  GroupedAttendance({required this.dateString, required this.sessions});

  DateTime get dateObj => DateTime.parse(dateString);

  String get totalHours {
    int totalMinutes = 0;
    for (var s in sessions) {
      final wh = s.workingHours;
      totalMinutes += _parseWorkingHoursToMinutes(wh);
    }
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hrs}h ${mins}m';
  }

  int _parseWorkingHoursToMinutes(String wh) {
    try {
      if (wh.contains(':')) {
        final parts = wh.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          return h * 60 + m;
        }
      } else if (wh.contains('h') || wh.contains('m')) {
        int h = 0;
        int m = 0;
        final hMatch = RegExp(r'(\d+)\s*h').firstMatch(wh);
        final mMatch = RegExp(r'(\d+)\s*m').firstMatch(wh);
        if (hMatch != null) h = int.parse(hMatch.group(1)!);
        if (mMatch != null) m = int.parse(mMatch.group(1)!);
        return h * 60 + m;
      }
    } catch (_) {}
    return 0;
  }

  String get overallStatus {
    final anyCheckedIn = sessions.any((s) => s.checkInTime != null && s.checkOutTime == null);
    if (anyCheckedIn) return 'CHECKED-IN';

    final anyLate = sessions.any((s) => s.status.toLowerCase() == 'late');
    final anyHalfDay = sessions.any((s) => s.status.toLowerCase() == 'half_day');
    final anyPresent = sessions.any((s) => s.status.toLowerCase() == 'present');

    if (anyPresent) return 'PRESENT';
    if (anyLate) return 'LATE';
    if (anyHalfDay) return 'HALF DAY';
    
    if (sessions.isNotEmpty) return sessions.first.status.toUpperCase();
    return 'ABSENT';
  }

  Color get statusColor {
    final status = overallStatus;
    switch (status) {
      case 'PRESENT': return kPresent;
      case 'CHECKED-IN': return kCheckedIn;
      case 'CHECKED-OUT': return kPresent;
      case 'LATE': return const Color(0xFFF59E0B);
      case 'HALF DAY': return kHalfDay;
      case 'ABSENT': return kAbsent;
      default: return kPresent;
    }
  }
}

// ─── Entry-point Widget ───────────────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  final User? employeeToView;
  const AttendanceScreen({super.key, this.employeeToView});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  User? _user;
  bool _loading = true;
  bool _showTeamView = false; // Toggle for managers/TLs to switch between own and team view

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _user = await AuthService().getUser();
    if (mounted) setState(() => _loading = false);
  }

  bool get _isCompanyAdmin =>
      _user?.role == 'system_admin' || _user?.role == 'company_admin';

  bool get _isManagerOrTL =>
      _user?.role == 'manager' || _user?.role == 'team_leader';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    // Direct routing if we are viewing a specific employee (e.g. clicked calendar in team roster)
    if (widget.employeeToView != null) {
      return EmployeeCalendarView(
        employee: widget.employeeToView!,
        onBack: () => Navigator.pop(context),
        currentUser: _user!,
        isOwnView: false,
      );
    }

    if (_isCompanyAdmin) {
      return AdminAttendanceScreen(currentUser: _user!);
    }

    if (_isManagerOrTL) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showTeamView = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_showTeamView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: !_showTeamView
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Text(
                      'My Records',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_showTeamView ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showTeamView = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showTeamView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _showTeamView
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Text(
                      'Team Attendance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _showTeamView ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _showTeamView
            ? AdminAttendanceScreen(currentUser: _user!)
            : EmployeeAttendanceScreen(currentUser: _user!),
      );
    }

    return EmployeeAttendanceScreen(currentUser: _user!);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADMIN ATTENDANCE SCREEN (Also serves Managers/TLs for their teams)
// ══════════════════════════════════════════════════════════════════════════════
class AdminAttendanceScreen extends StatefulWidget {
  final User currentUser;
  const AdminAttendanceScreen({super.key, required this.currentUser});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  bool _filterOpen = false;
  bool _groupByTeam = false;
  String _selectedMood = 'All';
  String _selectedEnergy = 'All';
  String? _selectedUserId;
  String _dateMode = 'today'; // Default display: today only
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedIndividualDate;
  final TextEditingController _searchCtrl = TextEditingController();

  User? _viewingEmployee;
  final Set<int> _expandedTeams = {};
  final Set<String> _expandedDates = {}; // expanded grouping date strings ('yyyy-MM-dd')

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    await Future.wait([
      p.fetchEmployees(),
      p.fetchTeams(),
      p.fetchHolidays(year: _selectedMonth.year),
      _fetchAttendance(p),
    ]);
  }

  Future<void> _fetchAttendance(AppProvider p) async {
    String? start;
    String? end;

    if (_selectedIndividualDate != null) {
      final str = DateFormat('yyyy-MM-dd').format(_selectedIndividualDate!);
      start = str;
      end = str;
    } else if (_dateMode == 'today') {
      start = DateFormat('yyyy-MM-dd').format(DateTime.now());
      end = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (_dateMode == 'today_yesterday') {
      start = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      end = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (_dateMode == 'month') {
      // Month range handled automatically below
    }

    if (_groupByTeam) {
      final dateStr = (_dateMode == 'today' && _selectedIndividualDate == null)
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : (_selectedIndividualDate != null ? DateFormat('yyyy-MM-dd').format(_selectedIndividualDate!) : null);
          
      final startDateStr = _dateMode == 'month'
          ? DateFormat('yyyy-MM-01').format(_selectedMonth)
          : (_dateMode == 'today_yesterday' ? start : null);
          
      final endDateStr = _dateMode == 'month'
          ? DateFormat('yyyy-MM-dd').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0))
          : (_dateMode == 'today_yesterday' ? end : null);

      await p.fetchAttendanceByTeams(date: dateStr, startDate: startDateStr, endDate: endDateStr);
    } else {
      await p.fetchAllAttendance(
        startDate: start ?? DateFormat('yyyy-MM-01').format(_selectedMonth),
        endDate: end ?? DateFormat('yyyy-MM-dd').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0)),
        userId: _selectedUserId != null ? int.tryParse(_selectedUserId!) : null,
      );
    }
  }

  void _applyFilters() {
    final p = context.read<AppProvider>();
    _fetchAttendance(p);
    setState(() => _filterOpen = false);
  }

  void _resetFilters() {
    setState(() {
      _groupByTeam = false;
      _selectedMood = 'All';
      _selectedEnergy = 'All';
      _selectedUserId = null;
      _dateMode = 'today';
      _selectedMonth = DateTime.now();
      _selectedIndividualDate = null;
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  String _getDateChipLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yest = now.subtract(const Duration(days: 1));
    if (date.year == yest.year && date.month == yest.month && date.day == yest.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(date);
  }

  Future<void> _selectIndividualDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedIndividualDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedIndividualDate = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _exportReport() async {
    final provider = context.read<AppProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      ),
    );

    try {
      final start = DateFormat('yyyy-MM-01').format(_selectedMonth);
      final end = DateFormat('yyyy-MM-dd').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));
      final uId = _selectedUserId != null ? int.tryParse(_selectedUserId!) : null;

      final response = await ApiService().getAllAttendance(
        startDate: start,
        endDate: end,
        userId: uId,
      );
      final List<dynamic> rawRecords = response['attendance'] ?? [];
      final List<Attendance> attendanceRecords = rawRecords.map((r) => Attendance.fromJson(r)).toList();

      final List<dynamic> leaves = await ApiService().fetchAllLeaves(userId: uId);

      List<User> targets = [];
      if (uId != null) {
        final emp = provider.employees.firstWhere((e) => e.id == uId, orElse: () {
          if (attendanceRecords.isNotEmpty && attendanceRecords.first.user != null) {
            return attendanceRecords.first.user!;
          }
          throw Exception('Employee not found in registry');
        });
        targets = [emp];
      } else {
        targets = List.from(provider.employees)..sort((a, b) => a.name.compareTo(b.name));
      }

      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      if (!mounted) return;

      if (targets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No employees found to export.')),
        );
        return;
      }

      final csvContent = _generateHorizontalCSV(
        selectedMonth: _selectedMonth,
        employees: targets,
        attendanceRecords: attendanceRecords,
        leaves: leaves,
        holidays: provider.holidays,
      );

      final monthStr = DateFormat('yyyy_MM').format(_selectedMonth);
      final fileName = uId != null 
          ? 'attendance_report_employee_${uId}_$monthStr.csv' 
          : 'attendance_report_all_$monthStr.csv';

      await saveAndShareFile(
        utf8.encode(csvContent),
        fileName,
        shareText: 'Attendance Report for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  // Frontend filters on the list
  List<GroupedAttendance> _groupedAndFiltered(List<Attendance> records) {
    // 1. Apply basic query filters locally
    final q = _searchCtrl.text.trim().toLowerCase();
    final step1 = records.where((r) {
      if (q.isNotEmpty) {
        final name = (r.user?.name ?? '').toLowerCase();
        final empId = (r.user?.employeeId ?? '').toLowerCase();
        if (!name.contains(q) && !empId.contains(q)) return false;
      }
      if (_selectedMood != 'All' && r.mood?.toLowerCase() != _selectedMood.toLowerCase()) return false;
      if (_selectedEnergy != 'All' && r.energyLevel?.toLowerCase() != _selectedEnergy.toLowerCase()) return false;
      return true;
    }).toList();

    // 2. Group by date + user so that each user has a single grouped row per day
    final Map<String, List<Attendance>> groups = {};
    for (var r in step1) {
      final key = '${r.date}_${r.userId}';
      groups.putIfAbsent(key, () => []).add(r);
    }

    return groups.entries.map((e) {
      return GroupedAttendance(
        dateString: e.value.first.date,
        sessions: e.value..sort((a, b) => (a.checkInTime ?? DateTime.now()).compareTo(b.checkInTime ?? DateTime.now())),
      );
    }).toList()..sort((a, b) => b.dateString.compareTo(a.dateString));
  }

  Map<String, dynamic>? _viewingTeamCalendar;

  Future<void> _promptSelectEmployeeForCalendar() async {
    final p = context.read<AppProvider>();
    final isManagerOrTL = widget.currentUser.role == 'manager' || widget.currentUser.role == 'team_leader';
    final List<User> filteredEmployees;
    if (isManagerOrTL) {
      final managedTeamIds = p.teams
          .where((t) => t['managerId'] == widget.currentUser.id || t['teamLeaderId'] == widget.currentUser.id)
          .map((t) => t['id'] as int)
          .toSet();
      filteredEmployees = p.employees.where((e) => e.id == widget.currentUser.id || (e.teamId != null && managedTeamIds.contains(e.teamId))).toList();
    } else {
      filteredEmployees = p.employees;
    }

    if (filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees found to view calendar.')),
      );
      return;
    }

    User? selectedEmp;
    final User? selected = await showDialog<User>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Text('Select Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 250),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose an employee to view their monthly attendance calendar.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<User>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      hint: const Text('Select an employee', style: TextStyle(fontSize: 13)),
                      items: filteredEmployees.map((e) => DropdownMenuItem<User>(
                        value: e,
                        child: Text(e.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedEmp = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selectedEmp);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('View Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _viewingEmployee = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewingEmployee != null) {
      return EmployeeCalendarView(
        employee: _viewingEmployee!,
        onBack: () => setState(() => _viewingEmployee = null),
        currentUser: widget.currentUser,
        isOwnView: false,
      );
    }

    if (_viewingTeamCalendar != null) {
      return TeamCalendarView(
        teamId: _viewingTeamCalendar!['teamId'] as int,
        teamName: _viewingTeamCalendar!['teamName'] as String,
        currentUser: widget.currentUser,
        onBack: () => setState(() => _viewingTeamCalendar = null),
      );
    }

    return Consumer<AppProvider>(
      builder: (ctx, p, _) {
        final filtered = _groupedAndFiltered(p.attendance);
        final activeFilterCount = [
          _selectedMood != 'All',
          _selectedEnergy != 'All',
          _selectedUserId != null,
          _groupByTeam,
          _selectedIndividualDate != null,
        ].where((e) => e).length;

        final isCompanyAdmin = widget.currentUser.role == 'system_admin' || widget.currentUser.role == 'company_admin';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: isCompanyAdmin ? AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            centerTitle: true,
            title: const Text(
              'All Attendance',
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B)),
                tooltip: 'View Employee Calendar',
                onPressed: _promptSelectEmployeeForCalendar,
              ),
              IconButton(
                icon: const Icon(Icons.file_download_rounded, color: Color(0xFF10B981)),
                tooltip: 'Export Excel/CSV',
                onPressed: _exportReport,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                onPressed: () => _load(),
              ),
            ],
          ) : null,
          body: RefreshIndicator(
            color: const Color(0xFF2563EB),
            onRefresh: () => _load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildSearchRow(activeFilterCount)),
                if (_filterOpen)
                  SliverToBoxAdapter(child: _buildFilterPanel(p)),
                SliverToBoxAdapter(child: _buildActiveChips()),
                if (p.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                    ),
                  )
                else if (_groupByTeam)
                  _buildTeamGrouped(p)
                else
                  _buildFlatList(filtered),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchRow(int activeFilterCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search employee name or ID...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _filterOpen = !_filterOpen),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: activeFilterCount > 0 ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: activeFilterCount > 0 ? Colors.white : const Color(0xFF64748B),
                    size: 20,
                  ),
                  if (activeFilterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '$activeFilterCount',
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(AppProvider p) {
    final isManagerOrTL = widget.currentUser.role == 'manager' || widget.currentUser.role == 'team_leader';
    final List<User> filteredEmployees;
    if (isManagerOrTL) {
      final managedTeamIds = p.teams
          .where((t) => t['managerId'] == widget.currentUser.id || t['teamLeaderId'] == widget.currentUser.id)
          .map((t) => t['id'] as int)
          .toSet();
      filteredEmployees = p.employees.where((e) => e.id == widget.currentUser.id || (e.teamId != null && managedTeamIds.contains(e.teamId))).toList();
    } else {
      filteredEmployees = p.employees;
    }
    final moods = ['All', 'Happy', 'Sad', 'Exhausted', 'Angry'];
    final moodEmojis = {'Happy': '😊', 'Sad': '😢', 'Exhausted': '😩', 'Angry': '😤'};
    final energies = ['All', 'Low', 'Medium', 'High'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _filterDateBtn('Today & Yesterday', 'today_yesterday')),
              const SizedBox(width: 10),
              Expanded(child: _filterDateBtn('Select Month', 'month')),
            ],
          ),
          if (_dateMode == 'month') ...[
            const SizedBox(height: 10),
            _monthPickerRow(),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedUserId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Row(
              children: [
                Icon(Icons.people_outline_rounded, color: Color(0xFF64748B), size: 20),
                SizedBox(width: 10),
                Text('All Employees', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All Employees', style: TextStyle(fontSize: 13))),
              ...filteredEmployees.map((e) => DropdownMenuItem<String>(
                value: e.id.toString(),
                child: Text('${e.name} (${e.employeeId ?? e.email})', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (v) => setState(() => _selectedUserId = v),
          ),
          const SizedBox(height: 14),
          const Text('FILTER BY MOOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: moods.map((m) {
                final selected = _selectedMood == m;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      m == 'All' ? '☀️ All Moods' : '${moodEmojis[m] ?? ''} $m',
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          const Text('FILTER BY ENERGY LEVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: energies.map((e) {
                final selected = _selectedEnergy == e;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEnergy = e),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      e == 'All' ? '⚡ All Energy' : '🔋 $e',
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_work_rounded, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),
                  const Text('Group by Team', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                  const SizedBox(width: 10),
                  Switch(
                    value: _groupByTeam,
                    onChanged: (v) => setState(() => _groupByTeam = v),
                    activeThumbColor: const Color(0xFF2563EB),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _resetFilters,
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Color(0xFFEF4444), size: 16),
                    SizedBox(width: 4),
                    Text('Reset Filters', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDateBtn(String label, String mode) {
    final selected = _dateMode == mode || (mode == 'today_yesterday' && _selectedIndividualDate != null);
    return GestureDetector(
      onTap: () {
        if (mode == 'today_yesterday') {
          _selectIndividualDate();
        } else {
          setState(() {
            _dateMode = mode;
            _selectedIndividualDate = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              _selectedIndividualDate != null && mode == 'today_yesterday'
                  ? _getDateChipLabel(_selectedIndividualDate!)
                  : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF2563EB) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthPickerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF2563EB)),
          onPressed: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
            _applyFilters();
          },
        ),
        Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
          onPressed: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
            _applyFilters();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.file_download_rounded, color: Color(0xFF10B981)),
          tooltip: 'Export Excel/CSV',
          onPressed: _exportReport,
        ),
      ],
    );
  }

  Widget _buildActiveChips() {
    final chips = <Widget>[];

    void clearDateFilter() {
      setState(() {
        _selectedIndividualDate = null;
        _dateMode = 'today';
        _applyFilters();
      });
    }

    if (_selectedIndividualDate != null) {
      chips.add(_chip(
        '📅 ${_getDateChipLabel(_selectedIndividualDate!)}',
        clearDateFilter,
        onTap: _selectIndividualDate,
      ));
    } else {
      if (_dateMode == 'today') {
        chips.add(_chip(
          '📅 Today',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      } else if (_dateMode == 'today_yesterday') {
        chips.add(_chip(
          '📅 Today & Yesterday',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      } else {
        chips.add(_chip(
          '📅 ${DateFormat('MMM yyyy').format(_selectedMonth)}',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      }
    }

    if (_groupByTeam) chips.add(_chip('👥 Grouped by Team', () => setState(() { _groupByTeam = false; _applyFilters(); })));
    if (_selectedMood != 'All') chips.add(_chip('Mood: $_selectedMood', () => setState(() { _selectedMood = 'All'; _applyFilters(); })));
    if (_selectedEnergy != 'All') chips.add(_chip('Energy: $_selectedEnergy', () => setState(() { _selectedEnergy = 'All'; _applyFilters(); })));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(String label, VoidCallback onRemove, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatList(List<GroupedAttendance> groupedRecords) {
    if (groupedRecords.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final group = groupedRecords[i];
          final dateKey = '${group.dateString}_${group.sessions.first.userId}';
          final expanded = _expandedDates.contains(dateKey);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GroupedAttendanceCard(
              group: group,
              expanded: expanded,
              onToggle: () => setState(() {
                if (expanded) {
                  _expandedDates.remove(dateKey);
                } else {
                  _expandedDates.add(dateKey);
                }
              }),
              onEmployeeTap: (u) => setState(() => _viewingEmployee = u),
            ),
          );
        },
        childCount: groupedRecords.length,
      ),
    );
  }

  Widget _buildTeamGrouped(AppProvider p) {
    final grouped = p.attendanceByTeams;
    if (grouped.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final teamData = grouped[i] as Map<String, dynamic>;
          final teamId = teamData['teamId'] as int?;
          final teamName = teamData['teamName'] as String? ?? 'Unknown Team';
          final records = (teamData['records'] as List<dynamic>)
              .map((r) => Attendance.fromJson(r as Map<String, dynamic>))
              .toList();
          final expanded = teamId != null
              ? _expandedTeams.contains(teamId)
              : _expandedTeams.contains(-1);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: AdminTeamGroupCard(
              teamId: teamId ?? -1,
              teamName: teamName,
              records: records,
              expanded: expanded,
              onToggle: () => setState(() {
                final id = teamId ?? -1;
                if (_expandedTeams.contains(id)) {
                  _expandedTeams.remove(id);
                } else {
                  _expandedTeams.add(id);
                }
              }),
              onEmployeeTap: (user) => setState(() => _viewingEmployee = user),
              expandedDates: _expandedDates,
              onRecordToggle: (key) => setState(() {
                if (_expandedDates.contains(key)) {
                  _expandedDates.remove(key);
                } else {
                  _expandedDates.add(key);
                }
              }),
              onTeamCalendarTap: (id, name) => setState(() => _viewingTeamCalendar = {'teamId': id, 'teamName': name}),
            ),
          );
        },
        childCount: grouped.length,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text('No attendance records found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          SizedBox(height: 4),
          Text('Try adjusting the filters or picking another date', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EMPLOYEE OWN ATTENDANCE SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class EmployeeAttendanceScreen extends StatefulWidget {
  final User currentUser;
  const EmployeeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  bool _calendarMode = false;
  DateTime? _selectedIndividualDate;

  Future<void> _selectIndividualDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedIndividualDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedIndividualDate = picked;
        _calendarMode = false; // Switch back to list view to show the selected date chip!
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegularEmployee = widget.currentUser.role == 'employee';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isRegularEmployee ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: const Text(
          'My Attendance',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF2563EB)),
            tooltip: 'Select individual date',
            onPressed: _selectIndividualDate,
          ),
        ],
      ) : null,
      body: Column(
        children: [
          // Sub-Header toggle bar for all users to switch between list and calendar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _calendarMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_calendarMode ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_rounded, color: !_calendarMode ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'List View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_calendarMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => setState(() => _calendarMode = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _calendarMode ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: _calendarMode ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Calendar View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _calendarMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _calendarMode
                ? EmployeeCalendarView(
                    employee: widget.currentUser,
                    currentUser: widget.currentUser,
                    isOwnView: true,
                  )
                : EmployeeListView(
                    currentUser: widget.currentUser,
                    selectedIndividualDate: _selectedIndividualDate,
                    onIndividualDateChanged: (d) => setState(() => _selectedIndividualDate = d),
                    onCalendarViewRequested: () => setState(() => _calendarMode = true),
                  ),
          ),
        ],
      ),
    );
  }
}

class EmployeeListView extends StatefulWidget {
  final User currentUser;
  final DateTime? selectedIndividualDate;
  final ValueChanged<DateTime?>? onIndividualDateChanged;
  final VoidCallback? onCalendarViewRequested;

  const EmployeeListView({
    super.key,
    required this.currentUser,
    this.selectedIndividualDate,
    this.onIndividualDateChanged,
    this.onCalendarViewRequested,
  });

  @override
  State<EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends State<EmployeeListView> {
  bool _filterOpen = false;
  String _selectedMood = 'All';
  String _selectedEnergy = 'All';
  String _dateMode = 'last_week'; // Default display: last 1 week's attendance
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedIndividualDate;
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _expandedDates = {};

  @override
  void initState() {
    super.initState();
    _selectedIndividualDate = widget.selectedIndividualDate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant EmployeeListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndividualDate != oldWidget.selectedIndividualDate) {
      setState(() {
        _selectedIndividualDate = widget.selectedIndividualDate;
      });
      _load();
    }
  }

  String _getDateChipLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yest = now.subtract(const Duration(days: 1));
    if (date.year == yest.year && date.month == yest.month && date.day == yest.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(date);
  }

  Future<void> _selectIndividualDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedIndividualDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedIndividualDate = picked;
      });
      if (widget.onIndividualDateChanged != null) {
        widget.onIndividualDateChanged!(picked);
      }
      _applyFilters();
    }
  }

  Future<void> _exportReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      ),
    );

    try {
      final response = await ApiService().getMyAttendance(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );

      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      if (!mounted) return;

      final List<dynamic> data = response['attendance'] ?? [];
      final List<Attendance> attendanceRecords = data.map((r) => Attendance.fromJson(r)).toList();

      final provider = context.read<AppProvider>();
      final List<dynamic> leaves = provider.leaves; // my leaves are loaded in _load()

      final csvContent = _generateHorizontalCSV(
        selectedMonth: _selectedMonth,
        employees: [widget.currentUser],
        attendanceRecords: attendanceRecords,
        leaves: leaves,
        holidays: provider.holidays,
      );

      final monthStr = DateFormat('yyyy_MM').format(_selectedMonth);
      final fileName = 'attendance_report_${widget.currentUser.name.replaceAll(' ', '_')}_$monthStr.csv';

      await saveAndShareFile(
        utf8.encode(csvContent),
        fileName,
        shareText: 'My Attendance Report for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    await p.fetchMyLeaves();
    await p.fetchHolidays(year: _selectedMonth.year);

    String? start;
    String? end;
    int? m;
    int? y;

    if (_selectedIndividualDate != null) {
      final str = DateFormat('yyyy-MM-dd').format(_selectedIndividualDate!);
      start = str;
      end = str;
    } else if (_dateMode == 'last_week') {
      start = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7)));
      end = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (_dateMode == 'today') {
      start = DateFormat('yyyy-MM-dd').format(DateTime.now());
      end = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (_dateMode == 'today_yesterday') {
      start = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      end = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (_dateMode == 'month') {
      m = _selectedMonth.month;
      y = _selectedMonth.year;
    }

    await p.fetchMyAttendance(
      startDate: start,
      endDate: end,
      month: m,
      year: y,
    );
  }

  void _applyFilters() {
    _load();
    setState(() => _filterOpen = false);
  }

  void _resetFilters() {
    setState(() {
      _selectedMood = 'All';
      _selectedEnergy = 'All';
      _dateMode = 'last_week';
      _selectedMonth = DateTime.now();
      _selectedIndividualDate = null;
      _searchCtrl.clear();
    });
    if (widget.onIndividualDateChanged != null) {
      widget.onIndividualDateChanged!(null);
    }
    _applyFilters();
  }

  List<GroupedAttendance> _groupedAndFiltered(List<Attendance> records) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final step1 = records.where((r) {
      if (q.isNotEmpty) {
        final comments = (r.taskComments ?? '').toLowerCase();
        final addr = (r.address ?? '').toLowerCase();
        if (!comments.contains(q) && !addr.contains(q)) return false;
      }
      if (_selectedMood != 'All' && r.mood?.toLowerCase() != _selectedMood.toLowerCase()) return false;
      if (_selectedEnergy != 'All' && r.energyLevel?.toLowerCase() != _selectedEnergy.toLowerCase()) return false;
      return true;
    }).toList();

    final Map<String, List<Attendance>> groups = {};
    for (var r in step1) {
      groups.putIfAbsent(r.date, () => []).add(r);
    }

    return groups.entries.map((e) {
      return GroupedAttendance(
        dateString: e.key,
        sessions: e.value..sort((a, b) => (a.checkInTime ?? DateTime.now()).compareTo(b.checkInTime ?? DateTime.now())),
      );
    }).toList()..sort((a, b) => b.dateString.compareTo(a.dateString));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, p, _) {
        final filtered = _groupedAndFiltered(p.attendance);
        final activeFilterCount = [
          _selectedMood != 'All',
          _selectedEnergy != 'All',
          _selectedIndividualDate != null,
        ].where((e) => e).length;

        return RefreshIndicator(
          color: const Color(0xFF2563EB),
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              
              SliverToBoxAdapter(child: _buildSearchRow(activeFilterCount)),
              if (_filterOpen)
                SliverToBoxAdapter(child: _buildFilterPanel()),
              SliverToBoxAdapter(child: _buildActiveChips()),
              
              if (p.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: const Column(children: [
                      Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('No attendance records found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Try resetting or changing filters', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                    ]),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final group = filtered[i];
                      final expanded = _expandedDates.contains(group.dateString);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: GroupedAttendanceCard(
                          group: group,
                          expanded: expanded,
                          onToggle: () => setState(() {
                            if (expanded) {
                              _expandedDates.remove(group.dateString);
                            } else {
                              _expandedDates.add(group.dateString);
                            }
                          }),
                          fallbackUser: widget.currentUser,
                          onEmployeeTap: (u) {
                            if (widget.onCalendarViewRequested != null) {
                              widget.onCalendarViewRequested!();
                            }
                          },
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchRow(int activeFilterCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search my records...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _filterOpen = !_filterOpen),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: activeFilterCount > 0 ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: activeFilterCount > 0 ? Colors.white : const Color(0xFF64748B),
                    size: 20,
                  ),
                  if (activeFilterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '$activeFilterCount',
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    final moods = ['All', 'Happy', 'Sad', 'Exhausted', 'Angry'];
    final moodEmojis = {'Happy': '😊', 'Sad': '😢', 'Exhausted': '😩', 'Angry': '😤'};
    final energies = ['All', 'Low', 'Medium', 'High'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _filterDateBtn('Today & Yesterday', 'today_yesterday')),
              const SizedBox(width: 10),
              Expanded(child: _filterDateBtn('Select Month', 'month')),
            ],
          ),
          if (_dateMode == 'month') ...[
            const SizedBox(height: 10),
            _monthPickerRow(),
          ],
          const SizedBox(height: 14),
          const Text('FILTER BY MOOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: moods.map((m) {
                final selected = _selectedMood == m;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      m == 'All' ? '☀️ All Moods' : '${moodEmojis[m] ?? ''} $m',
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          const Text('FILTER BY ENERGY LEVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: energies.map((e) {
                final selected = _selectedEnergy == e;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEnergy = e),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      e == 'All' ? '⚡ All Energy' : '🔋 $e',
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _resetFilters,
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Color(0xFFEF4444), size: 16),
                    SizedBox(width: 4),
                    Text('Reset Filters', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDateBtn(String label, String mode) {
    final selected = _dateMode == mode || (mode == 'today_yesterday' && _selectedIndividualDate != null);
    return GestureDetector(
      onTap: () {
        if (mode == 'today_yesterday') {
          _selectIndividualDate();
        } else {
          setState(() {
            _dateMode = mode;
            _selectedIndividualDate = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              _selectedIndividualDate != null && mode == 'today_yesterday'
                  ? _getDateChipLabel(_selectedIndividualDate!)
                  : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF2563EB) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthPickerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF2563EB)),
          onPressed: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
            _applyFilters();
          },
        ),
        Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
          onPressed: () {
            setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
            _applyFilters();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.file_download_rounded, color: Color(0xFF10B981)),
          tooltip: 'Export Excel/CSV',
          onPressed: _exportReport,
        ),
      ],
    );
  }

  Widget _buildActiveChips() {
    final chips = <Widget>[];

    void clearDateFilter() {
      if (widget.onIndividualDateChanged != null) {
        widget.onIndividualDateChanged!(null);
      }
      setState(() {
        _selectedIndividualDate = null;
        _dateMode = 'last_week'; // Default back to last_week for employee!
      });
      _applyFilters();
    }

    if (_selectedIndividualDate != null) {
      chips.add(_chip(
        '📅 ${_getDateChipLabel(_selectedIndividualDate!)}',
        clearDateFilter,
        onTap: _selectIndividualDate,
      ));
    } else {
      if (_dateMode == 'last_week') {
        chips.add(_chip(
          '📅 Last 7 Days',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      } else if (_dateMode == 'today') {
        chips.add(_chip(
          '📅 Today',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      } else if (_dateMode == 'today_yesterday') {
        chips.add(_chip(
          '📅 Today & Yesterday',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      } else {
        chips.add(_chip(
          '📅 ${DateFormat('MMM yyyy').format(_selectedMonth)}',
          clearDateFilter,
          onTap: _selectIndividualDate,
        ));
      }
    }

    if (_selectedMood != 'All') chips.add(_chip('Mood: $_selectedMood', () => setState(() { _selectedMood = 'All'; _applyFilters(); })));
    if (_selectedEnergy != 'All') chips.add(_chip('Energy: $_selectedEnergy', () => setState(() { _selectedEnergy = 'All'; _applyFilters(); })));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(String label, VoidCallback onRemove, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GROUPED ATTENDANCE CARD WIDGET
// ══════════════════════════════════════════════════════════════════════════════
class GroupedAttendanceCard extends StatelessWidget {
  final GroupedAttendance group;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(User)? onEmployeeTap;
  final User? fallbackUser;

  const GroupedAttendanceCard({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    this.onEmployeeTap,
    this.fallbackUser,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMM').format(group.dateObj);
    final user = group.sessions.first.user ?? fallbackUser;
    final statusColor = group.statusColor;
    final statusLabel = group.overallStatus;
    final bool isCheckedIn = statusLabel == 'CHECKED-IN';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // Left Color Accent
                Container(
                  width: 4,
                  height: 52,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User detail / Avatar row for admin/manager view (when fallbackUser is null and onEmployeeTap is non-null)
                      if (user != null && onEmployeeTap != null && fallbackUser == null) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${user.name}${user.employeeId != null ? ' (${user.employeeId})' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B), size: 14),
                          const SizedBox(width: 5),
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                          const Spacer(),
                          
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCheckedIn ? Icons.radio_button_checked : Icons.check_circle_rounded,
                                  color: statusColor,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Calendar View button chip (if user is non-null and onEmployeeTap is provided)
                      if (user != null && onEmployeeTap != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () => onEmployeeTap!(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF2563EB)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Calendar View',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          const Text('Total Hours: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          Text(group.totalHours, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                          const Spacer(),
                          const Text('Sessions: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Text('${group.sessions.length}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                IconButton(
                  icon: Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF94A3B8)),
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
          
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: List.generate(group.sessions.length, (idx) {
                  final s = group.sessions[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Session ${idx + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AttendanceDetailsScreen(record: s)),
                              ),
                              child: const Row(
                                children: [
                                  Text('Details', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                                  Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _sessionTime('Check-In', Icons.login_rounded, s.checkInTime, const Color(0xFF10B981)),
                            Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                            _sessionTime('Check-Out', Icons.logout_rounded, s.checkOutTime, const Color(0xFFEF4444)),
                            Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                            _sessionTime('Hours', Icons.timer_outlined, null, const Color(0xFF2563EB), label2: s.workingHours),
                          ],
                        ),
                        if (s.address != null && s.address!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFFE2E8F0), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  s.address!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (s.mood != null || s.energyLevel != null || s.distanceFromOffice != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (s.mood != null)
                                _tagChip(_moodEmoji(s.mood!), s.mood!.toUpperCase(), const Color(0xFF10B981)),
                              if (s.energyLevel != null)
                                _tagChip('🔋', s.energyLevel!.toUpperCase(), const Color(0xFF3B82F6)),
                              if (s.distanceFromOffice != null)
                                _tagChip(
                                  '📍',
                                  s.distanceFromOffice! < 1000
                                      ? '${s.distanceFromOffice!.toStringAsFixed(0)}m away'
                                      : '${(s.distanceFromOffice! / 1000).toStringAsFixed(2)}km away',
                                  const Color(0xFFF59E0B),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sessionTime(String label, IconData icon, DateTime? time, Color color, {String? label2}) {
    final timeStr = label2 ?? (time != null ? DateFormat('hh:mm a').format(time.toLocal()) : '--:--');
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(timeStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _tagChip(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$emoji $label', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _moodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy': return '😊';
      case 'sad': return '😢';
      case 'exhausted': return '😩';
      case 'angry': return '😤';
      default: return '😐';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADMIN TEAM GROUP CARD
// ══════════════════════════════════════════════════════════════════════════════
class AdminTeamGroupCard extends StatelessWidget {
  final int teamId;
  final String teamName;
  final List<Attendance> records;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(User) onEmployeeTap;
  final Set<String> expandedDates;
  final void Function(String) onRecordToggle;
  final void Function(int, String)? onTeamCalendarTap;

  const AdminTeamGroupCard({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.records,
    required this.expanded,
    required this.onToggle,
    required this.onEmployeeTap,
    required this.expandedDates,
    required this.onRecordToggle,
    this.onTeamCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    // Group records inside the team by user so that we don't display redundant tiles
    final Map<int, List<Attendance>> userGroups = {};
    for (var r in records) {
      userGroups.putIfAbsent(r.userId, () => []).add(r);
    }

    final presentCount = userGroups.keys.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(
                          '$presentCount member${presentCount != 1 ? "s" : ""} logged in today',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (teamId != -1 && onTeamCalendarTap != null)
                    IconButton(
                      icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
                      tooltip: 'View Team Calendar',
                      onPressed: () => onTeamCalendarTap!(teamId, teamName),
                    ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          if (expanded && userGroups.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text('No attendance records for this team today.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          if (expanded && userGroups.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
            Column(
              children: userGroups.entries.map((e) {
                final userSessions = e.value;
                final group = GroupedAttendance(dateString: userSessions.first.date, sessions: userSessions);
                final key = '${group.dateString}_${group.sessions.first.userId}';
                final isRecordExpanded = expandedDates.contains(key);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: GroupedAttendanceCard(
                    group: group,
                    expanded: isRecordExpanded,
                    onToggle: () => onRecordToggle(key),
                    onEmployeeTap: onEmployeeTap,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EMPLOYEE CALENDAR VIEW
// ══════════════════════════════════════════════════════════════════════════════
class EmployeeCalendarView extends StatefulWidget {
  final User employee;
  final VoidCallback? onBack;
  final User currentUser;
  final bool isOwnView;
  final DateTime? initialMonth;

  const EmployeeCalendarView({
    super.key,
    required this.employee,
    required this.currentUser,
    this.onBack,
    this.isOwnView = false,
    this.initialMonth,
  });

  @override
  State<EmployeeCalendarView> createState() => _EmployeeCalendarViewState();
}

class _EmployeeCalendarViewState extends State<EmployeeCalendarView> {
  DateTime _month = DateTime.now();
  List<Attendance> _records = [];
  List<dynamic> _leaves = [];
  bool _loading = true;
  DateTime? _selectedDate;
  List<Attendance> _dayRecords = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialMonth != null) {
      _month = widget.initialMonth!;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = context.read<AppProvider>();
      await p.fetchHolidays(year: _month.year);

      if (widget.isOwnView) {
        await p.fetchMyAttendance(month: _month.month, year: _month.year, showLoading: false);
        _records = List.from(p.attendance);
        await p.fetchMyLeaves();
        _leaves = List.from(p.leaves);
      } else {
        final res = await ApiService().getAllAttendance(
          userId: widget.employee.id,
          month: _month.month,
          year: _month.year,
        );
        _records = (res['attendance'] as List<dynamic>).map((j) => Attendance.fromJson(j)).toList();
        try {
          final leaveRes = await ApiService().fetchAllLeaves(userId: widget.employee.id);
          _leaves = leaveRes;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Calendar load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _selectedDate = null;
      _dayRecords = [];
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _selectedDate = null;
      _dayRecords = [];
    });
    _load();
  }

  DayStatus _statusForDay(int day, AppProvider p) {
    final date = DateTime(_month.year, _month.month, day);
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isFuture = date.isAfter(DateTime.now());
    final dateStr = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    final holiday = p.getHolidayForDate(date);
    if (holiday != null) return DayStatus.holiday;

    if (isFuture) return DayStatus.none;

    final isOnLeave = _leaves.any((l) {
      try {
        final status = (l['status'] ?? '').toString().toLowerCase();
        if (status != 'approved') return false;
        
        final startDt = DateTime.parse(l['startDate'] ?? l['start_date'] ?? '').toLocal();
        final endDt = DateTime.parse(l['endDate'] ?? l['end_date'] ?? '').toLocal();
        
        final start = DateTime(startDt.year, startDt.month, startDt.day);
        final end = DateTime(endDt.year, endDt.month, endDt.day);
        final current = DateTime(date.year, date.month, date.day);
        
        return !current.isBefore(start) && !current.isAfter(end);
      } catch (_) {
        return false;
      }
    });
    if (isOnLeave) return DayStatus.leave;

    final dayRecords = _records.where((r) => r.date == dateStr).toList();
    if (dayRecords.isEmpty) {
      if (isWeekend) return DayStatus.weekend;
      return DayStatus.absent;
    }
    
    final anyHalfDay = dayRecords.any((r) => r.status.toLowerCase() == 'half_day');
    final hasCheckout = dayRecords.any((r) => r.checkOutTime != null);
    
    if (anyHalfDay || !hasCheckout) return DayStatus.halfDay;
    return DayStatus.present;
  }

  void _onDayTap(int day, AppProvider p) {
    final dateStr = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final dayRecs = _records.where((r) => r.date == dateStr).toList();
    setState(() {
      _selectedDate = DateTime(_month.year, _month.month, day);
      _dayRecords = dayRecs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, p, _) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: (widget.onBack != null || !widget.isOwnView)
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                ),
                title: Text(
                  widget.isOwnView ? 'My Attendance' : '${widget.employee.name}\'s Calendar',
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                    onPressed: _load,
                  ),
                ],
              )
            : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Gradient Branding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.isOwnView
                            ? 'Viewing: My Calendar Summary'
                            : 'Viewing: ${widget.employee.name}\'s Summary',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Monthly Calendar Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: _loading
                    ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
                    : _buildCalendar(p),
              ),
              const SizedBox(height: 12),
              _buildLegend(),
              const SizedBox(height: 16),
              if (_selectedDate != null) _buildDayDetail(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(AppProvider p) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Mon, 7=Sun
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    final today = DateTime.now();
    const headers = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF2563EB)),
              onPressed: _prevMonth,
            ),
            Text(
              DateFormat('MMMM yyyy').format(_month),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: headers.map((h) => Expanded(
            child: Center(
              child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: daysInMonth + startOffset,
          itemBuilder: (_, idx) {
            if (idx < startOffset) return const SizedBox.shrink();
            final day = idx - startOffset + 1;
            final date = DateTime(_month.year, _month.month, day);
            final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
            final isSelected = _selectedDate?.day == day && _selectedDate?.month == _month.month && _selectedDate?.year == _month.year;
            final status = _statusForDay(day, p);
            return CalendarCell(
              day: day,
              status: status,
              isToday: isToday,
              isSelected: isSelected,
              onTap: () => _onDayTap(day, p),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _legendItem('Present', kPresent),
        _legendItem('Half Day', kHalfDay),
        _legendItem('Absent', kAbsent),
        _legendItem('Leave', kLeave),
        _legendItem('Holiday 🎉', kHoliday),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDayDetail(AppProvider p) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate!);
    final holiday = p.getHolidayForDate(_selectedDate!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 15),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            ],
          ),
          if (holiday != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kHoliday.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kHoliday.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(holiday.name, style: const TextStyle(color: kHoliday, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_dayRecords.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No attendance records for this day', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            ),
          ] else ...[
            Column(
              children: List.generate(_dayRecords.length, (idx) {
                final r = _dayRecords[idx];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceDetailsScreen(record: r))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Session ${idx + 1}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const Spacer(),
                                  _timeTag(Icons.login_rounded, r.checkInTime != null ? DateFormat('hh:mm a').format(r.checkInTime!.toLocal()) : '--:--', kPresent),
                                  const SizedBox(width: 10),
                                  _timeTag(Icons.logout_rounded, r.checkOutTime != null ? DateFormat('hh:mm a').format(r.checkOutTime!.toLocal()) : '--:--', kAbsent),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(r.workingHours, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeTag(IconData icon, String time, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(time, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Calendar cell ─────────────────────────────────────────────────────────────
enum DayStatus { present, absent, halfDay, leave, holiday, weekend, none }

class CalendarCell extends StatelessWidget {
  final int day;
  final DayStatus status;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const CalendarCell({
    super.key,
    required this.day,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  Color get _bg {
    if (isSelected) return const Color(0xFF2563EB);
    switch (status) {
      case DayStatus.present:  return kPresent.withValues(alpha: 0.15);
      case DayStatus.absent:   return kAbsent.withValues(alpha: 0.10);
      case DayStatus.halfDay:  return kHalfDay.withValues(alpha: 0.15);
      case DayStatus.leave:    return kLeave.withValues(alpha: 0.15);
      case DayStatus.holiday:  return kHoliday.withValues(alpha: 0.12);
      case DayStatus.weekend:  return const Color(0xFFF1F5F9);
      case DayStatus.none:     return Colors.transparent;
    }
  }

  Color get _textColor {
    if (isSelected) return Colors.white;
    switch (status) {
      case DayStatus.present:  return kPresent;
      case DayStatus.absent:   return kAbsent;
      case DayStatus.halfDay:  return kHalfDay;
      case DayStatus.leave:    return kLeave;
      case DayStatus.holiday:  return kHoliday;
      case DayStatus.weekend:  return const Color(0xFF94A3B8);
      case DayStatus.none:     return const Color(0xFF94A3B8);
    }
  }

  Color get _dotColor {
    switch (status) {
      case DayStatus.present:  return kPresent;
      case DayStatus.absent:   return kAbsent;
      case DayStatus.halfDay:  return kHalfDay;
      case DayStatus.leave:    return kLeave;
      case DayStatus.holiday:  return kHoliday;
      default:                  return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFF2563EB), width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: _textColor,
                fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (status != DayStatus.none && status != DayStatus.weekend && !isSelected)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
              ),
            if (status == DayStatus.holiday && !isSelected)
              const Text('🎉', style: TextStyle(fontSize: 6)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TEAM CALENDAR VIEW
// ══════════════════════════════════════════════════════════════════════════════
class TeamCalendarView extends StatefulWidget {
  final int teamId;
  final String teamName;
  final User currentUser;
  final VoidCallback onBack;
  final DateTime? initialMonth;

  const TeamCalendarView({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.currentUser,
    required this.onBack,
    this.initialMonth,
  });

  @override
  State<TeamCalendarView> createState() => _TeamCalendarViewState();
}

class _TeamCalendarViewState extends State<TeamCalendarView> {
  DateTime _month = DateTime.now();
  List<Attendance> _records = [];
  List<User> _teamMembers = [];
  List<dynamic> _leaves = [];
  bool _loading = true;
  DateTime? _selectedDate;
  List<Attendance> _dayRecords = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialMonth != null) {
      _month = widget.initialMonth!;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = context.read<AppProvider>();
      await p.fetchHolidays(year: _month.year);
      await p.fetchEmployees();

      // Filter team members
      _teamMembers = p.employees.where((e) => e.teamId == widget.teamId).toList();

      // Fetch team attendance for the monthly range
      final start = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-01';
      final end = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${DateTime(_month.year, _month.month + 1, 0).day}';

      final res = await ApiService().getAttendanceByTeams(
        startDate: start,
        endDate: end,
      );

      final List<dynamic> grouped = res['grouped'] ?? [];
      final teamData = grouped.firstWhere(
        (t) => t['teamId'] == widget.teamId,
        orElse: () => null,
      );

      if (teamData != null && teamData['records'] != null) {
        _records = (teamData['records'] as List<dynamic>)
            .map((j) => Attendance.fromJson(j))
            .toList();
      } else {
        _records = [];
      }

      // Load all leaves for this company
      try {
        final leaveRes = await ApiService().fetchAllLeaves();
        _leaves = leaveRes;
      } catch (_) {}

    } catch (e) {
      debugPrint('Team calendar load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _selectedDate = null;
      _dayRecords = [];
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _selectedDate = null;
      _dayRecords = [];
    });
    _load();
  }

  DayStatus _statusForDay(int day, AppProvider p) {
    final date = DateTime(_month.year, _month.month, day);
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isFuture = date.isAfter(DateTime.now());
    final dateStr = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    final holiday = p.getHolidayForDate(date);
    if (holiday != null) return DayStatus.holiday;

    if (isFuture) return DayStatus.none;

    // Calculate leaves first for each member
    int leaveCount = 0;
    for (var member in _teamMembers) {
      final isOnLeave = _leaves.any((l) {
        try {
          final uid = l['userId'] ?? l['user_id'];
          if (uid != member.id) return false;
          final status = (l['status'] ?? '').toString().toLowerCase();
          if (status != 'approved') return false;
          final startDt = DateTime.parse(l['startDate'] ?? l['start_date'] ?? '').toLocal();
          final endDt = DateTime.parse(l['endDate'] ?? l['end_date'] ?? '').toLocal();
          final start = DateTime(startDt.year, startDt.month, startDt.day);
          final end = DateTime(endDt.year, endDt.month, endDt.day);
          final current = DateTime(date.year, date.month, date.day);
          return !current.isBefore(start) && !current.isAfter(end);
        } catch (_) {
          return false;
        }
      });
      if (isOnLeave) {
        leaveCount++;
      }
    }

    final dayRecords = _records.where((r) => r.date == dateStr).toList();
    final presentUserIds = dayRecords.map((r) => r.userId).toSet();
    final presentCount = presentUserIds.length;

    final activeMembersCount = _teamMembers.length - leaveCount;
    if (activeMembersCount <= 0 && _teamMembers.isNotEmpty) {
      return DayStatus.leave;
    }

    if (presentCount >= activeMembersCount && activeMembersCount > 0) {
      return DayStatus.present;
    } else if (presentCount > 0) {
      return DayStatus.halfDay;
    }

    if (isWeekend) return DayStatus.weekend;
    return DayStatus.absent;
  }

  DayStatus _memberStatusForDay(User member, DateTime date, AppProvider p) {
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final holiday = p.getHolidayForDate(date);
    if (holiday != null) return DayStatus.holiday;

    final isOnLeave = _leaves.any((l) {
      try {
        final uid = l['userId'] ?? l['user_id'];
        if (uid != member.id) return false;
        final status = (l['status'] ?? '').toString().toLowerCase();
        if (status != 'approved') return false;
        
        final startDt = DateTime.parse(l['startDate'] ?? l['start_date'] ?? '').toLocal();
        final endDt = DateTime.parse(l['endDate'] ?? l['end_date'] ?? '').toLocal();
        
        final start = DateTime(startDt.year, startDt.month, startDt.day);
        final end = DateTime(endDt.year, endDt.month, endDt.day);
        final current = DateTime(date.year, date.month, date.day);
        
        return !current.isBefore(start) && !current.isAfter(end);
      } catch (_) {
        return false;
      }
    });
    if (isOnLeave) return DayStatus.leave;

    final memberRecords = _records.where((r) => r.userId == member.id && r.date == dateStr).toList();
    if (memberRecords.isEmpty) {
      if (isWeekend) return DayStatus.weekend;
      return DayStatus.absent;
    }

    final anyHalfDay = memberRecords.any((r) => r.status.toLowerCase() == 'half_day');
    final hasCheckout = memberRecords.any((r) => r.checkOutTime != null);

    if (anyHalfDay || !hasCheckout) return DayStatus.halfDay;
    return DayStatus.present;
  }

  void _onDayTap(int day, AppProvider p) {
    final dateStr = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final dayRecs = _records.where((r) => r.date == dateStr).toList();
    setState(() {
      _selectedDate = DateTime(_month.year, _month.month, day);
      _dayRecords = dayRecs;
    });
  }

  Color _statusColor(DayStatus status) {
    switch (status) {
      case DayStatus.present:  return kPresent;
      case DayStatus.absent:   return kAbsent;
      case DayStatus.halfDay:  return kHalfDay;
      case DayStatus.leave:    return kLeave;
      case DayStatus.holiday:  return kHoliday;
      case DayStatus.weekend:  return const Color(0xFF94A3B8);
      default:                  return const Color(0xFF94A3B8);
    }
  }

  String _statusLabel(DayStatus status) {
    switch (status) {
      case DayStatus.present:  return 'PRESENT';
      case DayStatus.absent:   return 'ABSENT';
      case DayStatus.halfDay:  return 'HALF DAY';
      case DayStatus.leave:    return 'LEAVE';
      case DayStatus.holiday:  return 'HOLIDAY';
      case DayStatus.weekend:  return 'WEEKEND';
      default:                  return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, p, _) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
            onPressed: widget.onBack,
          ),
          title: Text(
            '${widget.teamName} Calendar',
            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              onPressed: _load,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Summary Accent
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Team Roster size: ${_teamMembers.length} member${_teamMembers.length != 1 ? "s" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Calendar Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: _loading
                    ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
                    : _buildCalendarGrid(p),
              ),
              const SizedBox(height: 12),
              _buildLegend(),
              const SizedBox(height: 16),
              if (_selectedDate != null) _buildSelectedDateDetails(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(AppProvider p) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Mon, 7=Sun
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    final today = DateTime.now();
    const headers = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF2563EB)),
              onPressed: _prevMonth,
            ),
            Text(
              DateFormat('MMMM yyyy').format(_month),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: headers.map((h) => Expanded(
            child: Center(
              child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: daysInMonth + startOffset,
          itemBuilder: (_, idx) {
            if (idx < startOffset) return const SizedBox.shrink();
            final day = idx - startOffset + 1;
            final date = DateTime(_month.year, _month.month, day);
            final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
            final isSelected = _selectedDate?.day == day && _selectedDate?.month == _month.month && _selectedDate?.year == _month.year;
            final status = _statusForDay(day, p);
            return CalendarCell(
              day: day,
              status: status,
              isToday: isToday,
              isSelected: isSelected,
              onTap: () => _onDayTap(day, p),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _legendItem('All Present', kPresent),
        _legendItem('Partial Activity', kHalfDay),
        _legendItem('No Activity', kAbsent),
        _legendItem('Leave', kLeave),
        _legendItem('Holiday 🎉', kHoliday),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSelectedDateDetails(AppProvider p) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate!);
    final holiday = p.getHolidayForDate(_selectedDate!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 15),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            ],
          ),
          if (holiday != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kHoliday.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kHoliday.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(holiday.name, style: const TextStyle(color: kHoliday, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text('TEAM MEMBER STATUSES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 10),
          if (_teamMembers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No members in this team', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            )
          else
            Column(
              children: _teamMembers.map((member) {
                final status = _memberStatusForDay(member, _selectedDate!, p);
                final formattedDateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
                final memberRecs = _dayRecords.where((r) => r.userId == member.id && r.date == formattedDateStr).toList();
                return _buildMemberTile(member, status, memberRecs);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(User member, DayStatus status, List<Attendance> memberRecs) {
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    if (member.employeeId != null)
                      Text(member.employeeId!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (memberRecs.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 6),
            ...memberRecs.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.login_rounded, size: 12, color: kPresent),
                  const SizedBox(width: 4),
                  Text(
                    r.checkInTime != null ? DateFormat('hh:mm a').format(r.checkInTime!) : '--:--',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.logout_rounded, size: 12, color: kAbsent),
                  const SizedBox(width: 4),
                  Text(
                    r.checkOutTime != null ? DateFormat('hh:mm a').format(r.checkOutTime!) : '--:--',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    r.workingHours,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

String _generateHorizontalCSV({
  required DateTime selectedMonth,
  required List<User> employees,
  required List<Attendance> attendanceRecords,
  required List<dynamic> leaves,
  required List<Holiday> holidays,
}) {
  final int daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

  // 1. Build CSV Header
  final List<String> headerParts = [
    'Name',
    'Email',
    'Department',
    'Total Working Hours',
  ];
  for (int d = 1; d <= daysInMonth; d++) {
    headerParts.add(d.toString());
    headerParts.add('$d Sessions');
  }

  final String header = '${headerParts.join(',')}\n';

  // 2. Build rows for each employee
  final List<String> rows = [];

  for (var emp in employees) {
    double monthlyTotalHours = 0.0;
    final List<String> rowParts = [
      emp.name.replaceAll(',', ';'),
      emp.email.replaceAll(',', ';'),
      (emp.department ?? 'N/A').replaceAll(',', ';'),
    ];

    // Placeholder for monthly total working hours, we'll calculate and update it later.
    // Let's reserve an index in rowParts for 'Total Working Hours'
    final int totalHoursIndex = rowParts.length;
    rowParts.add(''); // Temp placeholder

    // Build days columns
    for (int d = 1; d <= daysInMonth; d++) {
      final dayDate = DateTime(selectedMonth.year, selectedMonth.month, d);
      final datePrefix = DateFormat('yyyy-MM-dd').format(dayDate);

      // Filter sessions on this day for this employee
      final daySessions = attendanceRecords.where((r) =>
        (r.userId == emp.id || r.user?.id == emp.id) &&
        r.date == datePrefix
      ).toList();

      // Check approved leaves for this day
      final hasApprovedLeave = leaves.any((l) {
        final applicantId = l['user_id'] ?? l['userId'] ?? (l['user'] != null ? l['user']['id'] : null);
        if (applicantId != emp.id) return false;

        final status = (l['status'] ?? '').toString().toLowerCase();
        if (status != 'approved') return false;

        final startDateStr = l['startDate'] ?? l['start_date'];
        final endDateStr = l['endDate'] ?? l['end_date'];
        if (startDateStr == null || endDateStr == null) return false;

        try {
          final startDate = DateTime.parse(startDateStr);
          final endDate = DateTime.parse(endDateStr);
          final dateToCheck = DateTime(dayDate.year, dayDate.month, dayDate.day);
          final startCompare = DateTime(startDate.year, startDate.month, startDate.day);
          final endCompare = DateTime(endDate.year, endDate.month, endDate.day);
          return !dateToCheck.isBefore(startCompare) && !dateToCheck.isAfter(endCompare);
        } catch (_) {
          return false;
        }
      });

      String status = '';
      String sessionsText = '';

      if (daySessions.isEmpty) {
        if (hasApprovedLeave) {
          status = 'L';
        } else {
          final isWeekend = dayDate.weekday == DateTime.saturday || dayDate.weekday == DateTime.sunday;
          final isHoliday = holidays.any((h) => h.date == datePrefix);
          if (isHoliday) {
            status = 'H';
          } else if (isWeekend) {
            status = 'WE';
          } else {
            status = 'AB';
          }
        }
      } else {
        // We have sessions
        final hasHalfDay = daySessions.any((s) => s.status.toLowerCase() == 'half_day');
        status = hasHalfDay ? 'HD' : 'P';

        double dayHours = 0.0;
        final List<String> sessionIntervals = [];
        for (var s in daySessions) {
          final checkInStr = s.checkInTime != null ? DateFormat('hh:mm a').format(s.checkInTime!.toLocal()) : 'N/A';
          final checkOutStr = s.checkOutTime != null ? DateFormat('hh:mm a').format(s.checkOutTime!.toLocal()) : 'Active';
          sessionIntervals.add('$checkInStr-$checkOutStr');

          if (s.checkInTime != null) {
            final end = s.checkOutTime ?? DateTime.now();
            dayHours += end.difference(s.checkInTime!).inMinutes / 60.0;
          }
        }

        sessionsText = '${sessionIntervals.join("; ")} [${dayHours.toStringAsFixed(2)} hrs]';
        monthlyTotalHours += dayHours;
      }

      rowParts.add(status);
      // Clean sessionsText to avoid CSV split issues
      rowParts.add('"${sessionsText.replaceAll('"', '""')}"');
    }

    // Set actual monthly total hours
    rowParts[totalHoursIndex] = '${monthlyTotalHours.toStringAsFixed(2)} hrs';
    rows.add(rowParts.join(','));
  }

  return header + rows.join('\n');
}
