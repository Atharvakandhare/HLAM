import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../utils/app_messages.dart';
import '../services/api_service.dart';
import 'company_settings_screen.dart';
import '../widgets/app_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _isUploadingPicture = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getUser();
    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    // Request Photos/Storage permissions explicitly as requested by user
    PermissionStatus status = await Permission.photos.request();
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        if (mounted) {
          AppMessages.showError(
            context,
            'Gallery & Storage permission is required to select and upload a profile picture. Please enable permission in App Settings.',
          );
        }
        return;
      }
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) return;

      if (_user?.isProfilePictureAdminSet == true) {
        if (mounted) {
          AppMessages.showError(context, 'Your profile picture has been locked by the administrator.');
        }
        return;
      }

      setState(() => _isUploadingPicture = true);
      
      final apiService = ApiService();
      final response = await apiService.uploadProfilePicture(image);
      final String relativeUrl = response['url'] ?? '';

      if (relativeUrl.isNotEmpty) {
        // Update user profile picture in DB
        await apiService.updateProfilePicture(relativeUrl);
        
        // Update local session
        final updatedUser = await apiService.getProfile();
        final userModel = User.fromJson(updatedUser['user'] ?? updatedUser);

        setState(() {
          _user = userModel;
        });

        if (mounted) {
          AppMessages.showSuccess(context, 'Profile picture updated successfully.');
        }
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('EACCES') || errMsg.contains('permission') || errMsg.contains('Permission')) {
          errMsg = 'Server directory write permission denied (EACCES). Please ask your server administrator to grant write permissions (chmod 775) to the backend uploads/ folder.';
        }
        AppMessages.showError(context, 'Failed to upload profile picture: $errMsg');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPicture = false);
      }
    }
  }

  Future<void> _deleteImage() async {
    if (_user?.profilePicture == null) return;
    
    if (_user?.isProfilePictureAdminSet == true) {
      AppMessages.showError(context, 'Your profile picture has been locked by the administrator.');
      return;
    }

    setState(() => _isUploadingPicture = true);

    try {
      final apiService = ApiService();
      await apiService.deleteProfilePicture();
      
      // Fetch latest profile
      final updatedUser = await apiService.getProfile();
      final userModel = User.fromJson(updatedUser['user'] ?? updatedUser);

      setState(() {
        _user = userModel;
      });

      if (mounted) {
        AppMessages.showSuccess(context, 'Profile picture removed.');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to remove profile picture: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPicture = false);
      }
    }
  }

  void _showChangePasswordSheet() {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    )
                  ],
                ),
                const SizedBox(height: 20),

                // Old Password
                const Text(
                  'CURRENT PASSWORD',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: oldPasswordCtrl,
                  obscureText: obscureOld,
                  validator: (val) => val == null || val.isEmpty ? 'Current password is required' : null,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setSheetState(() => obscureOld = !obscureOld),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // New Password
                const Text(
                  'NEW PASSWORD',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'New password is required';
                    if (val.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••',
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm New Password
                const Text(
                  'CONFIRM NEW PASSWORD',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureConfirm,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Confirm password is required';
                    if (val != newPasswordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••',
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(sheetCtx); // Close sheet
                      
                      try {
                        final provider = Provider.of<AppProvider>(context, listen: false);
                        await provider.changePassword(oldPasswordCtrl.text, newPasswordCtrl.text);
                        if (mounted) {
                          AppMessages.showSuccess(context, 'Password changed successfully.');
                        }
                      } catch (e) {
                        if (mounted) {
                          AppMessages.showError(context, e.toString());
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        content: const Text('Are you sure you want to log out from the application?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<AppProvider>(context, listen: false);
              await provider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final emp = _user!;
    final bool isAdmin = emp.role == 'system_admin' || emp.role == 'company_admin';

    // Parse DOB if available
    String formattedDob = 'N/A';
    if (emp.dob != null && emp.dob!.isNotEmpty) {
      try {
        final dobDate = DateTime.parse(emp.dob!);
        formattedDob = DateFormat('dd MMMM yyyy').format(dobDate);
      } catch (_) {
        formattedDob = emp.dob!;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Profile Card Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar Section
                  Stack(
                    children: [
                      _isUploadingPicture
                          ? const CircleAvatar(
                              radius: 50,
                              backgroundColor: Color(0xFFF8FAFC),
                              child: CircularProgressIndicator(),
                            )
                          : AppAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                              imageUrl: emp.profilePicture != null && emp.profilePicture!.isNotEmpty
                                  ? '${ApiService.baseUrl.replaceAll('/api', '')}${emp.profilePicture}'
                                  : null,
                              fallback: Text(
                                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 36, color: Color(0xFF2563EB)),
                              ),
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF2563EB),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (emp.profilePicture != null && emp.profilePicture!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _deleteImage,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Remove Photo', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Name & Role
                  Text(
                    emp.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      emp.role.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile info sections
            if (isAdmin) ...[
              // For system_admin and company_admin
              _buildSectionHeader('ADMINISTRATOR INFORMATION'),
              _buildInfoCard([
                _buildInfoRow(Icons.person_outline_rounded, 'Name', emp.name),
                _buildInfoRow(Icons.email_outlined, 'Email Address', emp.email),
                _buildInfoRow(Icons.badge_outlined, 'Role / Designation', emp.role.toUpperCase().replaceAll('_', ' ')),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('COMPANY INFORMATION'),
              _buildInfoCard([
                _buildInfoRow(Icons.business_outlined, 'Company Name', emp.companyName ?? 'N/A'),
              ]),
              const SizedBox(height: 24),
            ] else ...[
              // For employees, managers, team leaders
              _buildSectionHeader('EMPLOYEE INFORMATION'),
              _buildInfoCard([
                _buildInfoRow(Icons.badge_outlined, 'Employee ID', emp.employeeId ?? 'N/A'),
                _buildInfoRow(Icons.business_outlined, 'Department', emp.department ?? 'N/A'),
                _buildInfoRow(Icons.email_outlined, 'Email Address', emp.email),
                _buildInfoRow(Icons.cake_outlined, 'Date of Birth', formattedDob),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('TEAM ASSIGNMENTS'),
              _buildInfoCard([
                _buildInfoRow(Icons.business_outlined, 'Company Name', emp.companyName ?? 'N/A'),
                _buildInfoRow(Icons.groups_outlined, 'Assigned Team Name', emp.teamName ?? 'N/A'),
                _buildInfoRow(Icons.person_pin_outlined, 'Team Manager Name', emp.managerName ?? 'N/A'),
                _buildInfoRow(Icons.assignment_ind_outlined, 'Team Leader Name', emp.teamLeaderName ?? 'N/A'),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('WORK ENVIRONMENT'),
              _buildInfoCard([
                if (!(emp.department?.toLowerCase() == 'marketing' &&
                      (emp.workType == 'Field Work' || emp.workType == 'Office + Field Work')))
                  _buildInfoRow(Icons.location_on_outlined, 'Work Mode', emp.workMode ?? 'Work From Office'),
                _buildInfoRow(Icons.work_outline_rounded, 'Work Type', emp.workType ?? 'N/A'),
                _buildInfoRow(Icons.map_outlined, 'State', emp.state ?? 'N/A'),
                _buildInfoRow(Icons.location_city_outlined, 'City', emp.city ?? 'N/A'),
              ]),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader('ACCOUNT SECURITY'),
            _buildInfoCard([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                title: const Text('Update Account Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Keep your login secure and up to date.', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: _showChangePasswordSheet,
              ),
              if (isAdmin) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF8B5CF6), size: 22),
                  ),
                  title: const Text('Configure Company Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Update GPS geofence, times, and radius.', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CompanySettingsScreen()),
                    );
                  },
                ),
              ],
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }
}
