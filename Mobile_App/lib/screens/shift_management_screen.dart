import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/shift.dart';
import '../models/user.dart';
import '../utils/app_messages.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await Future.wait([
        provider.fetchShifts(),
        provider.fetchEmployees(),
      ]);
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to load data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Shift Management',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Shifts Config'),
            Tab(text: 'Assign Shift'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildShiftsTab(),
                _buildAssignTab(),
              ],
            ),
    );
  }

  Widget _buildShiftsTab() {
    final provider = Provider.of<AppProvider>(context);
    final activeShifts = provider.shifts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShiftFormDialog(null),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add New Shift', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: activeShifts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No company shifts configured yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add New Shift" to create your first shift.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: activeShifts.length,
              itemBuilder: (context, index) {
                final shift = activeShifts[index];
                return _buildShiftCard(shift);
              },
            ),
    );
  }

  Widget _buildShiftCard(Shift shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shift.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5), size: 20),
                      onPressed: () => _showShiftFormDialog(shift),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      onPressed: () => _confirmDeleteShift(shift),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimePill('Check In', shift.checkInTime.substring(0, 5), const Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePill('Check Out', shift.checkOutTime.substring(0, 5), Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGraceText('Late Check-In', '${shift.lateInLimit}m'),
                _buildGraceText('Early Check-Out', '${shift.earlyOutLimit}m'),
                _buildGraceText('Late Check-Out', '${shift.lateOutLimit}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraceText(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildAssignTab() {
    final provider = Provider.of<AppProvider>(context);
    final users = provider.employees.where((u) => u.role != 'system_admin').toList();

    return users.isEmpty
        ? Center(
            child: Text(
              'No employees registered to assign shifts.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final assignedShift = provider.shifts.firstWhere(
                (s) => s.id == user.defaultShiftId,
                orElse: () => Shift(
                  id: 0,
                  companyId: 0,
                  name: 'Standard Office Hours',
                  checkInTime: '09:00:00',
                  checkOutTime: '18:00:00',
                  lateInLimit: 15,
                  lateOutLimit: 15,
                  earlyInLimit: 15,
                  earlyOutLimit: 15,
                  isActive: true,
                ),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.role.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAssignShiftDialog(user),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: user.defaultShiftId != null
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.defaultShiftId != null ? assignedShift.name : 'Select Shift',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: user.defaultShiftId != null
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  void _showShiftFormDialog(Shift? existingShift) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingShift?.name ?? '');
    
    TimeOfDay checkInTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay checkOutTime = const TimeOfDay(hour: 18, minute: 0);
    
    if (existingShift != null) {
      try {
        final checkInParts = existingShift.checkInTime.split(':');
        checkInTime = TimeOfDay(hour: int.parse(checkInParts[0]), minute: int.parse(checkInParts[1]));
        final checkOutParts = existingShift.checkOutTime.split(':');
        checkOutTime = TimeOfDay(hour: int.parse(checkOutParts[0]), minute: int.parse(checkOutParts[1]));
      } catch (_) {}
    }

    final checkInCtrl = TextEditingController(
      text: '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}',
    );
    final checkOutCtrl = TextEditingController(
      text: '${checkOutTime.hour.toString().padLeft(2, '0')}:${checkOutTime.minute.toString().padLeft(2, '0')}',
    );
    
    final lateInCtrl = TextEditingController(text: existingShift?.lateInLimit.toString() ?? '15');
    final earlyOutCtrl = TextEditingController(text: existingShift?.earlyOutLimit.toString() ?? '15');
    final lateOutCtrl = TextEditingController(text: existingShift?.lateOutLimit.toString() ?? '15');

    Future<void> selectTime(BuildContext ctx, bool isCheckIn) async {
      final TimeOfDay? picked = await showTimePicker(
        context: ctx,
        initialTime: isCheckIn ? checkInTime : checkOutTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF4F46E5),
                onPrimary: Colors.white,
                onSurface: Color(0xFF0F172A),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        if (isCheckIn) {
          checkInTime = picked;
          checkInCtrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        } else {
          checkOutTime = picked;
          checkOutCtrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        }
      }
    }

    String formatTime(TimeOfDay tod) {
      final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final minute = tod.minute.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => SafeArea(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom +
                  MediaQuery.of(sheetCtx).padding.bottom +
                  24,
              left: 24,
              right: 24,
              top: 24,
            ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingShift == null ? 'Create New Shift' : 'Edit Shift',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Shift Name
                  const Text(
                    'SHIFT NAME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Morning Shift',
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF4F46E5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Timings Row
                  const Text(
                    'SHIFT TIMINGS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => selectTime(sheetCtx, true).then((_) => setSheetState(() {})),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.login_rounded, size: 16, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'CHECK IN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formatTime(checkInTime),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => selectTime(sheetCtx, false).then((_) => setSheetState(() {})),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.logout_rounded, size: 16, color: Colors.orange),
                                    const SizedBox(width: 6),
                                    Text(
                                      'CHECK OUT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formatTime(checkOutTime),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Grace Period Settings
                  const Text(
                    'GRACE LIMIT CONFIGURATIONS (MINUTES)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: lateInCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Late Check-In grace period',
                            prefixIcon: const Icon(Icons.timer_outlined, color: Color(0xFF4F46E5), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Late check-in limit is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: earlyOutCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Early Check-Out grace period',
                            prefixIcon: const Icon(Icons.timer_off_outlined, color: Colors.orange, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Early check-out limit is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lateOutCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Late Check-Out grace period',
                            prefixIcon: const Icon(Icons.hourglass_bottom_rounded, color: Colors.blueGrey, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Late check-out limit is required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(sheetCtx);
                        
                        final shiftData = {
                          if (existingShift != null) 'id': existingShift.id,
                          'name': nameCtrl.text.trim(),
                          'checkInTime': '${checkInCtrl.text}:00',
                          'checkOutTime': '${checkOutCtrl.text}:00',
                          'lateInLimit': int.parse(lateInCtrl.text.trim()),
                          'earlyOutLimit': int.parse(earlyOutCtrl.text.trim()),
                          'lateOutLimit': int.parse(lateOutCtrl.text.trim()),
                        };

                        try {
                          final provider = Provider.of<AppProvider>(context, listen: false);
                          if (existingShift == null) {
                            await provider.createShift(shiftData);
                            if (mounted) AppMessages.showSuccess(context, 'Shift created successfully.');
                          } else {
                            await provider.updateShift(shiftData);
                            if (mounted) AppMessages.showSuccess(context, 'Shift updated successfully.');
                          }
                        } catch (e) {
                          if (mounted) AppMessages.showError(context, e.toString());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        existingShift == null ? 'Create Shift' : 'Save Shift',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  void _confirmDeleteShift(Shift shift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Shift', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete the shift "${shift.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final provider = Provider.of<AppProvider>(context, listen: false);
                await provider.deleteShift(shift.id);
                if (mounted) AppMessages.showSuccess(context, 'Shift deleted successfully.');
              } catch (e) {
                if (mounted) AppMessages.showError(context, e.toString());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAssignShiftDialog(User user) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    int? activeSelectedId = user.defaultShiftId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Assign Shift to ${user.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int?>(
                    title: const Text('Standard Office Hours (No Shift)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    value: null,
                    // ignore: deprecated_member_use
                    groupValue: activeSelectedId,
                    // ignore: deprecated_member_use
                    onChanged: (val) => setState(() => activeSelectedId = val),
                  ),
                  ...provider.shifts.map((s) => RadioListTile<int?>(
                        title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('${s.checkInTime.substring(0, 5)} - ${s.checkOutTime.substring(0, 5)}', style: const TextStyle(fontSize: 11)),
                        value: s.id,
                        // ignore: deprecated_member_use
                        groupValue: activeSelectedId,
                        // ignore: deprecated_member_use
                        onChanged: (val) => setState(() => activeSelectedId = val),
                      )),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final provider = Provider.of<AppProvider>(context, listen: false);
                await provider.assignShift(user.id, activeSelectedId);
                if (mounted) AppMessages.showSuccess(context, 'Shift assigned successfully.');
              } catch (e) {
                if (mounted) AppMessages.showError(context, e.toString());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
