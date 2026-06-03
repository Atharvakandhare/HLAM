import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'apply_leave_screen.dart';

class EmployeeLeaveDetailsScreen extends StatefulWidget {
  final dynamic leave;

  const EmployeeLeaveDetailsScreen({super.key, required this.leave});

  @override
  State<EmployeeLeaveDetailsScreen> createState() => _EmployeeLeaveDetailsScreenState();
}

class _EmployeeLeaveDetailsScreenState extends State<EmployeeLeaveDetailsScreen> {
  late dynamic _currentLeave;

  @override
  void initState() {
    super.initState();
    _currentLeave = widget.leave;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  int _calculateDays(String startStr, String endStr) {
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      return end.difference(start).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String startDateStr = _currentLeave['startDate'] ?? '';
    final String endDateStr = _currentLeave['endDate'] ?? '';
    final String reason = _currentLeave['reason'] ?? '';
    final String status = _currentLeave['status'] ?? 'pending';
    final String? adminComment = _currentLeave['adminComment'];

    String formattedDates = '';
    int totalDays = 0;
    try {
      final start = DateTime.parse(startDateStr);
      final end = DateTime.parse(endDateStr);
      formattedDates = "${DateFormat('dd MMM yyyy').format(start)}  -  ${DateFormat('dd MMM yyyy').format(end)}";
      totalDays = _calculateDays(startDateStr, endDateStr);
    } catch (_) {
      formattedDates = "$startDateStr to $endDateStr";
      totalDays = 1;
    }

    final statusColor = _getStatusColor(status);
    final bool isPending = status.toLowerCase() == 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Leave Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1: Status Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPending
                            ? Icons.hourglass_empty_rounded
                            : status.toLowerCase() == 'approved'
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_outlined,
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Application Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Card 2: Date Grid Layout
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.date_range_outlined, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              const Text(
                                'Date Range',
                                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedDates.replaceAll('  -  ', '\nto '),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$totalDays',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalDays == 1 ? 'Day' : 'Days',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card 3: Statement / Reason for Leave
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F4F9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        const Text(
                          'Statement of Purpose',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Color(0xFFF1F4F9)),
                    ),
                    Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Card 4: Admin Feedback (if already processed)
              if (adminComment != null && adminComment.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.feedback_outlined, size: 16, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            'Admin Review Comment',
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Colors.transparent),
                      ),
                      Text(
                        adminComment,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final result = await navigator.push(
                        MaterialPageRoute(
                          builder: (context) => ApplyLeaveScreen(leave: _currentLeave),
                        ),
                      );
                      if (result == true) {
                        navigator.pop(true);
                      }
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 24, color: Colors.white),
                    label: const Text(
                      'Edit Leave Application',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
