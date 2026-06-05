import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../utils/app_messages.dart';

class AdminLeaveDetailsScreen extends StatefulWidget {
  final dynamic leave;

  const AdminLeaveDetailsScreen({super.key, required this.leave});

  @override
  State<AdminLeaveDetailsScreen> createState() => _AdminLeaveDetailsScreenState();
}

class _AdminLeaveDetailsScreenState extends State<AdminLeaveDetailsScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).fetchLeaveQuota(userId: widget.leave['userId']);
    });
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

  void _showActionDialog(BuildContext context, String action) {
    final commentController = TextEditingController();
    final bool isApprove = action == 'approved';
    final accentColor = isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isApprove ? 'Approve Leave Request' : 'Reject Leave Request',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to ${isApprove ? "approve" : "reject"} this leave request?',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Review Comment/Feedback:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: commentController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Enter feedback for employee...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              setState(() => _isProcessing = true);

              try {
                final provider = Provider.of<AppProvider>(context, listen: false);
                final leaveId = widget.leave['id'];
                final comment = commentController.text.trim();

                await provider.updateLeaveStatus(leaveId, action, comment.isEmpty ? null : comment);
                if (context.mounted) {
                  AppMessages.showSuccess(context, 'Leave application has been $action.');
                  Navigator.pop(context, true); // Pop details screen and return success
                }
              } catch (e) {
                if (context.mounted) {
                  AppMessages.showError(context, e.toString());
                }
              } finally {
                if (context.mounted) {
                  setState(() => _isProcessing = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isApprove ? 'Approve' : 'Reject', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2563EB).withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showActionDialog(context, 'rejected'),
                icon: const Icon(Icons.close, size: 20, color: Color(0xFFDC2626)),
                label: const Text(
                  'Reject',
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEBEE),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showActionDialog(context, 'approved'),
                icon: const Icon(Icons.check, size: 20, color: Colors.white),
                label: const Text(
                  'Approve',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final String startDateStr = leave['startDate'] ?? '';
    final String endDateStr = leave['endDate'] ?? '';
    final String reason = leave['reason'] ?? '';
    final String status = leave['status'] ?? 'pending';
    final String? adminComment = leave['adminComment'];
    final dynamic user = leave['user'];

    final String employeeName = user != null ? user['name'] ?? 'Employee' : 'Employee';
    final String department = user != null ? user['department'] ?? 'Staff' : 'Staff';
    final String empId = user != null ? user['employeeId'] ?? '-' : '-';
    final String email = user != null ? user['email'] ?? '-' : '-';

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
    final bool isApproved = status.toLowerCase() == 'approved';

    final isPaidRequest = leave['isPaidRequest'] ?? false;
    final allowNextMonthQuota = leave['allowNextMonthQuota'] ?? false;

    final quota = Provider.of<AppProvider>(context).leaveQuota;
    final int availableThisMonth = (quota?['availableThisMonth'] as num?)?.toInt() ?? 0;
    final int availableNextMonth = (quota?['availableNextMonth'] as num?)?.toInt() ?? 0;

    int previewPaid = 0;
    int previewBorrowed = 0;
    int previewUnpaid = totalDays;

    if (isApproved) {
      previewPaid = (leave['paidDays'] as num?)?.toInt() ?? 0;
      previewBorrowed = (leave['nextMonthPaidDays'] as num?)?.toInt() ?? 0;
      previewUnpaid = (leave['unpaidDays'] as num?)?.toInt() ?? totalDays;
    } else if (isPaidRequest) {
      if (totalDays <= availableThisMonth) {
        previewPaid = totalDays;
        previewBorrowed = 0;
        previewUnpaid = 0;
      } else {
        previewPaid = availableThisMonth;
        final int rem = totalDays - availableThisMonth;
        if (allowNextMonthQuota) {
          previewBorrowed = rem <= availableNextMonth ? rem : availableNextMonth;
          previewUnpaid = rem - previewBorrowed;
        } else {
          previewBorrowed = 0;
          previewUnpaid = rem;
        }
      }
    } else {
      previewPaid = 0;
      previewBorrowed = 0;
      previewUnpaid = totalDays;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Leave Application',
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card 1: Profile & Status
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
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                child: Text(
                                  employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'E',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      employeeName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        department,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Dynamic embedded status badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F4F9)),
                          ),
                          _buildProfileDetailRow(Icons.badge_outlined, 'Employee ID', empId),
                          const SizedBox(height: 10),
                          _buildProfileDetailRow(Icons.email_outlined, 'Email', email),
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
                                    Text(
                                      'Date Range',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold),
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
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
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

                    // Card 3: Paid Leave Policy & Allocation Preview
                    Container(
                      width: double.infinity,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Text(
                                isApproved ? 'Paid Leave Allocation Details' : 'Paid Leave & Allocation Preview',
                                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFF1F4F9)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Requested as Paid Leave:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text(isPaidRequest ? 'YES' : 'NO', style: TextStyle(color: isPaidRequest ? const Color(0xFF16A34A) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Allow Borrowing Next Month:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text(allowNextMonthQuota ? 'YES' : 'NO', style: TextStyle(color: allowNextMonthQuota ? const Color(0xFF2563EB) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          if (!isApproved) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Applicant\'s Quota (This Month):', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                Text('$availableThisMonth Days', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Applicant\'s Quota (Next Month):', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                Text('$availableNextMonth Days', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFF1F4F9)),
                          ),
                          Text(
                            isApproved ? 'ALLOCATION DETAILS:' : 'EXPECTED ALLOCATION:',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Paid Days:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('$previewPaid Days', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Borrowed Next Month:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('$previewBorrowed Days', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Unpaid Days:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('$previewUnpaid Days', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card 4: Statement / Reason for Leave
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
                              Text(
                                'Statement of Purpose',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold),
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
                    
                    // Card 5: Admin Feedback (if already processed)
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
      bottomNavigationBar: isPending ? _buildBottomActionSheet() : null,
    );
  }
}
