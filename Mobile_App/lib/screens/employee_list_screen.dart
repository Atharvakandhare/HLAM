import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'add_employee_screen.dart';
import '../widgets/app_avatar.dart';


class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  String _searchQuery = '';
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).fetchEmployees();
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService().getUser();
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allEmployees = provider.employees;
    final employees = _searchQuery.isEmpty
        ? allEmployees
        : allEmployees
            .where((e) =>
                e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.employeeId ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.department ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search employees...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
            // Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${employees.length} ${employees.length == 1 ? 'member' : 'members'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: employees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No employees found',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: employees.length,
                      itemBuilder: (context, index) => _buildEmployeeCard(employees[index], provider),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add_employee'),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmployeeCard(User emp, AppProvider provider) {
    // Detect if this card is a cross-company admin (system_admin viewing other companies' company_admin)
    final bool isCrossCompany = _currentUser != null &&
        emp.companyId != null &&
        _currentUser!.companyId != null &&
        emp.companyId != _currentUser!.companyId;

    Widget avatar = AppAvatar(
      radius: 26,
      backgroundColor: isCrossCompany
          ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
          : const Color(0xFF2563EB).withValues(alpha: 0.1),
      imageUrl: emp.profilePicture != null && emp.profilePicture!.isNotEmpty
          ? '${ApiService.baseUrl.replaceAll('/api', '')}${emp.profilePicture}'
          : null,
      fallback: Text(
        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: isCrossCompany ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          avatar,
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
                    Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      emp.employeeId ?? 'N/A',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.business_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        emp.department ?? 'N/A',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Company name shown for cross-company admins (system_admin sees other companies' company_admins)
                if (isCrossCompany && emp.companyName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.domain_rounded, size: 13, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          emp.companyName!,
                          style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: emp.isActive
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        emp.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: emp.isActive ? const Color(0xFF4CAF50) : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCrossCompany
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                            : const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        emp.role.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isCrossCompany ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    if (isCrossCompany) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          'OTHER CO.',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
            // system_admin cannot edit company_admin from other companies via mobile (backend enforces)
            onPressed: isCrossCompany ? null : () async {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEmployeeScreen(employee: emp),
                ),
              );
              appProvider.fetchEmployees();
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.delete_outline,
              color: isCrossCompany ? Colors.grey.shade300 : Colors.redAccent,
              size: 22,
            ),
            onPressed: isCrossCompany ? null : () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Employee'),
                  content: Text('Are you sure you want to delete ${emp.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await provider.deleteEmployee(emp.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
