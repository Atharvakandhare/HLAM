import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../utils/app_messages.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final Map<int, bool> _expandedTeams = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.fetchTeams();
      provider.fetchEmployees();
    });
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      provider.fetchTeams(),
      provider.fetchEmployees(),
    ]);
  }

  void _showCreateTeamDialog() {
    String selectedTeamType = "IT Team";
    final customNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Create New Team',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedTeamType,
                  decoration: InputDecoration(
                    labelText: 'Select Team Template',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: "IT Team", child: Text("IT Team")),
                    DropdownMenuItem(value: "HR Team", child: Text("HR Team")),
                    DropdownMenuItem(value: "Marketing Team", child: Text("Marketing Team")),
                    DropdownMenuItem(value: "Sales Team", child: Text("Sales Team")),
                    DropdownMenuItem(value: "Operations Team", child: Text("Operations Team")),
                    DropdownMenuItem(value: "Finance Team", child: Text("Finance Team")),
                    DropdownMenuItem(value: "Support Team", child: Text("Support Team")),
                    DropdownMenuItem(value: "Other", child: Text("Other (Custom Name)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedTeamType = val;
                      });
                    }
                  },
                ),
                if (selectedTeamType == "Other") ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Enter custom team name...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final finalName = selectedTeamType == "Other" ? customNameController.text.trim() : selectedTeamType;
                  if (finalName.isEmpty) {
                    AppMessages.showError(context, 'Team name is required.');
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await Provider.of<AppProvider>(context, listen: false).createTeam(finalName);
                    if (mounted) AppMessages.showSuccess(context, 'Team "$finalName" created successfully.');
                  } catch (e) {
                    if (mounted) AppMessages.showError(context, 'Failed to create team: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameTeamDialog(int teamId, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Team',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        content: TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                AppMessages.showError(context, 'Team name is required.');
                return;
              }
              Navigator.pop(ctx);
              try {
                await Provider.of<AppProvider>(context, listen: false).updateTeam(teamId, name: name);
                if (mounted) AppMessages.showSuccess(context, 'Team renamed to "$name".');
              } catch (e) {
                if (mounted) AppMessages.showError(context, 'Failed to rename team: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTeam(int teamId, String teamName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Team',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
        ),
        content: Text(
          'Are you sure you want to delete "$teamName"? All members of this team will be unassigned.',
          style: const TextStyle(fontSize: 14),
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
                await Provider.of<AppProvider>(context, listen: false).deleteTeam(teamId);
                if (mounted) AppMessages.showSuccess(context, 'Team deleted successfully.');
              } catch (e) {
                if (mounted) AppMessages.showError(context, 'Failed to delete team: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final teams = provider.teams;
    final assignableList = provider.employees.where((u) => ['manager', 'team_leader', 'employee'].contains(u.role) && u.isActive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Manage Teams',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF2563EB), size: 28),
            onPressed: _showCreateTeamDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF2563EB),
        child: teams.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No Teams Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateTeamDialog,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Create a Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: teams.length,
                itemBuilder: (context, idx) {
                  final team = teams[idx];
                  final int teamId = team['id'];
                  final String teamName = team['name'];
                  final Map<String, dynamic>? mgr = team['manager'];
                  final Map<String, dynamic>? tl = team['teamLeader'];
                  final int membersCount = team['membersCount'] ?? 0;
                  final bool isExpanded = _expandedTeams[teamId] ?? false;

                  final List<User> teamMembers = provider.employees.where((u) => u.teamId == teamId && u.isActive).toList();

                  final List<User> managerDropdownList = List.from(assignableList);
                  if (mgr != null && !managerDropdownList.any((u) => u.id == mgr['id'])) {
                    final existingEmp = provider.employees.firstWhere(
                      (u) => u.id == mgr['id'],
                      orElse: () => User(
                        id: mgr['id'],
                        name: mgr['name'] ?? 'Unknown',
                        email: mgr['email'] ?? '',
                        role: 'manager',
                        isActive: false,
                      ),
                    );
                    managerDropdownList.add(existingEmp);
                  }

                  final List<User> tlDropdownList = List.from(assignableList);
                  if (tl != null && !tlDropdownList.any((u) => u.id == tl['id'])) {
                    final existingEmp = provider.employees.firstWhere(
                      (u) => u.id == tl['id'],
                      orElse: () => User(
                        id: tl['id'],
                        name: tl['name'] ?? 'Unknown',
                        email: tl['email'] ?? '',
                        role: 'team_leader',
                        isActive: false,
                      ),
                    );
                    tlDropdownList.add(existingEmp);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Card Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.groups_rounded, color: Color(0xFF8B5CF6), size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teamName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$membersCount active members',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                                onPressed: () => _showRenameTeamDialog(teamId, teamName),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                                onPressed: () => _confirmDeleteTeam(teamId, teamName),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Dropdowns for assignments
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ASSIGNED MANAGER',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  fillColor: const Color(0xFFF8FAFC),
                                  filled: true,
                                ),
                                initialValue: mgr != null ? mgr['id'] : null,
                                hint: const Text('No Manager Assigned', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('None (Unassign)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ),
                                  ...managerDropdownList.map((m) => DropdownMenuItem<int>(
                                        value: m.id,
                                        child: Text('${m.name} (${m.email})', style: const TextStyle(fontSize: 13)),
                                      )),
                                ],
                                onChanged: (val) async {
                                  try {
                                    if (val != null) {
                                      await provider.updateTeam(teamId, managerId: val);
                                    } else {
                                      await provider.updateTeam(teamId, clearManager: true);
                                    }
                                    if (context.mounted) AppMessages.showSuccess(context, 'Manager assignment updated.');
                                  } catch (e) {
                                    if (context.mounted) AppMessages.showError(context, 'Failed to assign manager: $e');
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'ASSIGNED TEAM LEADER',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  fillColor: const Color(0xFFF8FAFC),
                                  filled: true,
                                ),
                                initialValue: tl != null ? tl['id'] : null,
                                hint: const Text('No Team Leader Assigned', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('None (Unassign)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ),
                                  ...tlDropdownList.map((t) => DropdownMenuItem<int>(
                                        value: t.id,
                                        child: Text('${t.name} (${t.email})', style: const TextStyle(fontSize: 13)),
                                      )),
                                ],
                                onChanged: (val) async {
                                  try {
                                    if (val != null) {
                                      await provider.updateTeam(teamId, teamLeaderId: val);
                                    } else {
                                      await provider.updateTeam(teamId, clearTeamLeader: true);
                                    }
                                    if (context.mounted) AppMessages.showSuccess(context, 'Team Leader assignment updated.');
                                  } catch (e) {
                                    if (context.mounted) AppMessages.showError(context, 'Failed to assign Team Leader: $e');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        // Expandable Team Members List
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedTeams[teamId] = !isExpanded;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                              border: Border(top: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'View Team Members (${teamMembers.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Container(
                            color: const Color(0xFFF8FAFC),
                            child: teamMembers.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                      'No employees explicitly assigned to this team yet.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: teamMembers.length,
                                    itemBuilder: (context, memberIdx) {
                                      final member = teamMembers[memberIdx];
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFF2563EB),
                                          radius: 18,
                                          child: Text(
                                            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                          ),
                                        ),
                                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        subtitle: Text('${member.role.toUpperCase()} • ${member.department ?? "General"}', style: const TextStyle(fontSize: 11)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.redAccent, size: 18),
                                          tooltip: 'Remove from Team',
                                          onPressed: () async {
                                            try {
                                              await provider.assignUserToTeam(member.id, null);
                                              if (context.mounted) AppMessages.showSuccess(context, '${member.name} removed from team.');
                                            } catch (e) {
                                              if (context.mounted) AppMessages.showError(context, 'Failed to remove member: $e');
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}
