import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../utils/app_messages.dart';
import '../services/auth_service.dart';
import 'add_employee_screen.dart';
import 'admin_leaves_screen.dart';
import 'attendance_screen.dart';

class ManagerTeamScreen extends StatefulWidget {
  const ManagerTeamScreen({super.key});

  @override
  State<ManagerTeamScreen> createState() => _ManagerTeamScreenState();
}

class _ManagerTeamScreenState extends State<ManagerTeamScreen> {
  User? _currentUser;
  bool _isLoading = true;
  final Map<int, bool> _expandedTeams = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await AuthService().getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      provider.fetchTeams(),
      provider.fetchEmployees(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      provider.fetchTeams(),
      provider.fetchEmployees(),
    ]);
  }

  List<dynamic> _getManagedTeams(List<dynamic> allTeams) {
    if (_currentUser == null) return [];
    final currentUserId = _currentUser!.id;
    final role = _currentUser!.role;

    if (role == 'system_admin' || role == 'company_admin') {
      // Admins see all company teams
      return allTeams;
    }

    return allTeams.where((team) {
      if (role == 'manager') {
        return team['manager']?['id'] == currentUserId;
      } else if (role == 'team_leader') {
        return team['teamLeader']?['id'] == currentUserId;
      }
      return false;
    }).toList();
  }

  void _showAddExistingMemberSheet(int teamId, String teamName, List<User> existingMembers) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Filter company employees who are active, not in this team, and are assignable (employee/TL/manager)
    final assignableList = provider.employees.where((u) {
      final isNotInCurrentTeam = u.teamId != teamId;
      final isActive = u.isActive;
      // Allow adding regular employees. Managers can add team leaders too.
      final isManager = _currentUser?.role == 'manager' || _currentUser?.role == 'company_admin' || _currentUser?.role == 'system_admin';
      final isEligibleRole = isManager ? ['team_leader', 'employee'].contains(u.role) : u.role == 'employee';
      
      return isNotInCurrentTeam && isActive && isEligibleRole && u.id != _currentUser?.id;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          List<User> filteredList = List.from(assignableList);
          
          return SafeArea(
            child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Sheet Handler Bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add to $teamName',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select an active company colleague to add as a member.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (val) {
                      setSheetState(() {
                        filteredList = assignableList
                            .where((u) => u.name.toLowerCase().contains(val.toLowerCase()) || 
                                          u.email.toLowerCase().contains(val.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Employee List
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No assignable colleagues found',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, idx) {
                            final emp = filteredList[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  child: Text(
                                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('${emp.role.toUpperCase()} • ${emp.department ?? "General"}', style: const TextStyle(fontSize: 11)),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(sheetCtx);
                                    try {
                                      await provider.addTeamMember(teamId, emp.id);
                                      if (context.mounted) {
                                        AppMessages.showSuccess(context, '${emp.name} added to team successfully.');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        AppMessages.showError(context, 'Failed to add member: $e');
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          },
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

  void _confirmRemoveMember(int teamId, User member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Member',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
        ),
        content: Text(
          'Are you sure you want to remove ${member.name} from this team? They will be unassigned but remain active in the company.',
          style: const TextStyle(fontSize: 14, height: 1.4),
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
                await Provider.of<AppProvider>(context, listen: false).assignUserToTeam(member.id, null);
                if (mounted) {
                  AppMessages.showSuccess(context, '${member.name} removed from the team.');
                }
              } catch (e) {
                if (mounted) {
                  AppMessages.showError(context, 'Failed to remove member: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allTeams = provider.teams;
    final managedTeams = _getManagedTeams(allTeams);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Team Console',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF2563EB),
              child: managedTeams.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: managedTeams.length,
                      itemBuilder: (context, idx) {
                        final team = managedTeams[idx];
                        final int teamId = team['id'];
                        final String teamName = team['name'];
                        final Map<String, dynamic>? mgr = team['manager'];
                        final Map<String, dynamic>? tl = team['teamLeader'];
                        final bool isExpanded = _expandedTeams[teamId] ?? true; // Default expanded for easier access
                        
                        // Extract members belonging to this team
                        final List<User> teamMembers = provider.employees.where((u) => u.teamId == teamId && u.isActive).toList();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Team Header Card
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.groups_rounded, color: Color(0xFF2563EB), size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            teamName,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${teamMembers.length} active team members',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _expandedTeams[teamId] = !isExpanded;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Manager / TL Badges row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (mgr != null)
                                      _buildRoleBadge('MANAGER', mgr['name'], const Color(0xFF2563EB)),
                                    if (tl != null)
                                      _buildRoleBadge('LEADER', tl['name'], const Color(0xFF8B5CF6)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),

                              // Quick Admin Actions Hub for this specific team
                              _buildTeamQuickActions(teamId, teamName, teamMembers),

                              const Divider(height: 1),
                              
                              // Expanded Members list
                              if (isExpanded) ...[
                                Container(
                                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                  child: const Text(
                                    'TEAM ROSTER',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
                                  ),
                                ),
                                teamMembers.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        child: Text(
                                          'This team has no assigned members. Use the actions above to add colleagues.',
                                          style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic, height: 1.4),
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: teamMembers.length,
                                        itemBuilder: (context, memberIdx) {
                                          final member = teamMembers[memberIdx];
                                          return _buildMemberTile(teamId, member);
                                        },
                                      ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_rounded, size: 64, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Assigned Teams',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Text(
              'You are not currently assigned as a Manager or Team Leader to any active team in this company.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String roleLabel, String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        '$roleLabel: $name',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTeamQuickActions(int teamId, String teamName, List<User> members) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Text(
              'TEAM CONSOLE ACTIONS',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
            ),
          ),
          Row(
            children: [
              // Add colleague
              Expanded(
                child: _buildActionBtn(
                  'Add Member',
                  Icons.person_add_alt_rounded,
                  const Color(0xFF2563EB),
                  () => _showAddExistingMemberSheet(teamId, teamName, members),
                ),
              ),
              const SizedBox(width: 8),
              
              // Register new
              Expanded(
                child: _buildActionBtn(
                  'New Employee',
                  Icons.person_add_alt_1_rounded,
                  const Color(0xFF10B981),
                  () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEmployeeScreen(preFilledTeamId: teamId),
                      ),
                    );
                    if (result == true) {
                      _refreshData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Review leaves
              Expanded(
                child: _buildActionBtn(
                  'Review Leaves',
                  Icons.edit_document,
                  const Color(0xFFF59E0B),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminLeavesScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      shadowColor: color.withValues(alpha: 0.05),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(int teamId, User member) {
    final bool isTL = member.role == 'team_leader';
    final roleColor = isTL ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.1),
          radius: 20,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(fontWeight: FontWeight.bold, color: roleColor),
          ),
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${member.role.toUpperCase().replaceAll('_', ' ')} • ${member.department ?? "General"}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 2),
            Text(
              member.email,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View Attendance icon button
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 20),
              tooltip: 'Check Attendance',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(employeeToView: member),
                  ),
                );
              },
            ),
            
            // Remove from Team icon button (Only show if not the manager/TL itself!)
            if (member.id != _currentUser?.id)
              IconButton(
                icon: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Remove from Team',
                onPressed: () => _confirmRemoveMember(teamId, member),
              ),
          ],
        ),
      ),
    );
  }
}
