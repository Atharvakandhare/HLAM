import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_messages.dart';

class CompanyRegistrationsScreen extends StatefulWidget {
  const CompanyRegistrationsScreen({super.key});

  @override
  State<CompanyRegistrationsScreen> createState() => _CompanyRegistrationsScreenState();
}

class _CompanyRegistrationsScreenState extends State<CompanyRegistrationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _allCompanies = [];

  List<dynamic> _pendingCompanies = [];
  List<dynamic> _approvedCompanies = [];
  List<dynamic> _rejectedCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await _apiService.fetchCompanies();
      setState(() {
        _allCompanies = companies;
        _pendingCompanies = companies.where((c) => c['status'] == 'pending').toList();
        _approvedCompanies = companies.where((c) => c['status'] == 'approved').toList();
        _rejectedCompanies = companies.where((c) => c['status'] == 'rejected').toList();
      });
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to fetch companies: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performApprove(int companyId) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.approveCompany(companyId);
      if (mounted) {
        AppMessages.showSuccess(context, 'Company approved successfully and welcome email sent.');
      }
      await _loadCompanies();
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Approval failed: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performReject(int companyId, String reason) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.rejectCompany(companyId, reason);
      if (mounted) {
        AppMessages.showSuccess(context, 'Company registration rejected and email notification sent.');
      }
      await _loadCompanies();
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Rejection failed: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      if (dateStr.length >= 10) return dateStr.substring(0, 10);
      return dateStr;
    }
  }

  Future<void> _showApproveDialog(BuildContext context, int companyId, String companyName) async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Approve Company',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Are you sure you want to approve "$companyName"? This will activate their account and send a welcome notification email to their administrator.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == true) {
        _performApprove(companyId);
      }
    });
  }

  Future<void> _showRejectDialog(BuildContext context, int companyId, String companyName) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Reject $companyName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please specify the reason for rejecting this company registration. The admin will be notified via email.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Rejection reason is required' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g., Incomplete documentation or invalid business email.',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null && value is String && value.isNotEmpty) {
        _performReject(companyId, value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Company Registrations',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Color(0xFF0F172A)),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF2563EB),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF2563EB),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCompanyList(_pendingCompanies, 'pending'),
                    _buildCompanyList(_approvedCompanies, 'approved'),
                    _buildCompanyList(_rejectedCompanies, 'rejected'),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCompanyList(List<dynamic> list, String tabType) {
    if (list.isEmpty) {
      IconData emptyIcon = Icons.business_center_outlined;
      String emptyMsg = 'No companies found';
      if (tabType == 'pending') {
        emptyIcon = Icons.domain_verification_rounded;
        emptyMsg = 'No pending registration requests';
      } else if (tabType == 'approved') {
        emptyIcon = Icons.domain_rounded;
        emptyMsg = 'No approved companies yet';
      } else if (tabType == 'rejected') {
        emptyIcon = Icons.domain_disabled_rounded;
        emptyMsg = 'No rejected companies';
      }

      return RefreshIndicator(
        onRefresh: _loadCompanies,
        color: const Color(0xFF2563EB),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 64, color: const Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  Text(
                    emptyMsg,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pull down to refresh lists',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCompanies,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final company = list[index];
          final admins = company['admins'] as List<dynamic>? ?? [];
          final adminName = admins.isNotEmpty ? admins[0]['name'] : 'N/A';
          final adminEmail = admins.isNotEmpty ? admins[0]['email'] : 'N/A';
          final dateCreated = _formatDate(company['created_at']);

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
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getStatusColor(tabType).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(tabType),
                          color: _getStatusColor(tabType),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company['name'] ?? 'Unnamed Company',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Request Date: $dateCreated',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Color(0xFFF1F5F9), height: 24),
                          
                          // Admin info
                          _buildDetailRow(Icons.person_outline_rounded, 'Admin Name', adminName),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.email_outlined, 'Admin Email', adminEmail),
                          const SizedBox(height: 12),

                          // If approved show stats
                          if (tabType == 'approved') ...[
                            _buildDetailRow(Icons.groups_outlined, 'Employees count', 
                              '${company['employeesCount'] ?? 0} (Managers: ${company['managersCount'] ?? 0}, TLs: ${company['teamLeadersCount'] ?? 0})'),
                            const SizedBox(height: 12),
                            _buildDetailRow(Icons.hub_outlined, 'Teams count', '${company['teamsCount'] ?? 0}'),
                          ],

                          // Rejection Reason
                          if (tabType == 'rejected') ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFEE2E2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rejection Reason',
                                    style: TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    company['rejection_reason'] ?? 'No reason provided.',
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Action Buttons for pending requests
                          if (tabType == 'pending') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showRejectDialog(context, company['id'], company['name']),
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(color: Color(0xFFEF4444)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showApproveDialog(context, company['id'], company['name']),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.domain_rounded;
      case 'rejected':
        return Icons.domain_disabled_rounded;
      default:
        return Icons.domain_verification_rounded;
    }
  }
}
