import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../utils/app_messages.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';


class AddEmployeeScreen extends StatefulWidget {
  final User? employee;
  final int? preFilledTeamId;

  const AddEmployeeScreen({super.key, this.employee, this.preFilledTeamId});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();

  String _selectedWorkMode = 'Work From Office';
  String? _selectedWorkType;
  String? _selectedDepartment;
  int? _selectedTeamId;
  DateTime? _selectedDob;
  XFile? _pickedImage;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isUploadingPicture = false;
  bool _isEditMode = false;
  String _selectedRole = 'employee';

  User? _currentUser;
  bool _isCustomState = false;
  bool _isCustomCity = false;
  String? _dropdownState;
  String? _dropdownCity;

  static const Map<String, List<String>> _indiaStatesAndCities = {
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Tirupati', 'Kurnool', 'Other'],
    'Arunachal Pradesh': ['Itanagar', 'Naharlagun', 'Tawang', 'Pasighat', 'Other'],
    'Assam': ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Nagaon', 'Other'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Darbhanga', 'Other'],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg', 'Other'],
    'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Other'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Other'],
    'Haryana': ['Faridabad', 'Gurugram', 'Panipat', 'Ambala', 'Yamunanagar', 'Other'],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Other'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro Steel City', 'Other'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Hubballi-Dharwad', 'Mangaluru', 'Belagavi', 'Other'],
    'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam', 'Other'],
    'Madhya Pradesh': ['Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Other'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Nashik', 'Aurangabad', 'Solapur', 'Other'],
    'Manipur': ['Imphal', 'Thoubal', 'Bishnupur', 'Other'],
    'Meghalaya': ['Shillong', 'Tura', 'Jowai', 'Other'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Champhai', 'Other'],
    'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Other'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Sambalpur', 'Puri', 'Other'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Other'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Ajmer', 'Udaipur', 'Other'],
    'Sikkim': ['Gangtok', 'Namchi', 'Geyzing', 'Other'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Other'],
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar', 'Other'],
    'Tripura': ['Agartala', 'Dharmanagar', 'Udaipur', 'Other'],
    'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi', 'Meerut', 'Noida', 'Prayagraj', 'Other'],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Haldwani', 'Roorkee', 'Other'],
    'West Bengal': ['Kolkata', 'Howrah', 'Asansol', 'Siliguri', 'Durgapur', 'Other'],
    'Andaman and Nicobar Islands': ['Port Blair', 'Other'],
    'Chandigarh': ['Chandigarh', 'Other'],
    'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Diu', 'Silvassa', 'Other'],
    'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Other'],
    'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Other'],
    'Ladakh': ['Leh', 'Kargil', 'Other'],
    'Lakshadweep': ['Kavaratti', 'Other'],
    'Puducherry': ['Puducherry', 'Karaikal', 'Other'],
    'Other': ['Other']
  };

  List<String> _getAvailableRoles() {
    final role = _currentUser?.role;
    List<String> roles = [];
    if (role == 'system_admin' || role == 'company_admin') {
      roles = ['manager', 'team_leader', 'employee'];
    } else if (role == 'manager') {
      roles = ['team_leader', 'employee'];
    } else if (role == 'team_leader') {
      roles = ['employee'];
    } else {
      roles = ['employee'];
    }
    
    // Ensure that in edit mode, the employee's current role is included
    if (_isEditMode && !roles.contains(_selectedRole)) {
      roles.insert(0, _selectedRole);
    }
    return roles;
  }


  final List<String> _workModes = [
    'Work From Office',
    'Work From Home',
    'Remote Work',
  ];
  final List<String> _workTypes = [
    'Field Work',
    'Office Work',
    'Office+Field work',
  ];

  String? _getBackendWorkType(String? localWorkType) {
    if (localWorkType == 'Field Work') return 'Field Work';
    if (localWorkType == 'Office Work') return 'Work From Office';
    if (localWorkType == 'Office+Field work') return 'Office + Field Work';
    return localWorkType;
  }

  String? _getLocalWorkType(String? backendWorkType) {
    if (backendWorkType == 'Field Work') return 'Field Work';
    if (backendWorkType == 'Work From Office') return 'Office Work';
    if (backendWorkType == 'Office + Field Work') return 'Office+Field work';
    return backendWorkType;
  }

  String? _getDepartmentFromDefault(String? dept) {
    if (dept == null || dept.isEmpty) return null;
    final defaultList = [
      'Marketing',
      'IT',
      'Engineering',
      'HR',
      'Sales',
      'Finance',
      'Operations',
    ];
    for (final d in defaultList) {
      if (d.toLowerCase() == dept.toLowerCase()) {
        return d;
      }
    }
    return dept;
  }

  List<DropdownMenuItem<String>> _getDepartmentDropdownItems() {
    final defaultList = [
      'Marketing',
      'IT',
      'Engineering',
      'HR',
      'Sales',
      'Finance',
      'Operations',
    ];
    final List<String> list = List.from(defaultList);
    if (_selectedDepartment != null && !list.contains(_selectedDepartment)) {
      list.add(_selectedDepartment!);
    }
    return list
        .map(
          (dept) => DropdownMenuItem<String>(
            value: dept,
            child: Text(
              dept,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.employee != null;
    _loadCurrentUser();
    _initializeForm();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService().getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        provider.fetchTeams();
      }
    });
  }

  void _initializeForm() {
    if (_isEditMode && widget.employee != null) {
      final emp = widget.employee!;
      _nameController.text = emp.name;
      _emailController.text = emp.email;
      _employeeIdController.text = emp.employeeId ?? '';
      _departmentController.text = emp.department ?? '';
      _selectedDepartment = _getDepartmentFromDefault(emp.department);
      _stateController.text = emp.state ?? '';
      _cityController.text = emp.city ?? '';
      _selectedWorkMode = emp.workMode ?? 'Work From Office';
      _selectedWorkType = _getLocalWorkType(emp.workType);
      _selectedTeamId = emp.teamId;
      _selectedRole = emp.role;

      if (_stateController.text.isNotEmpty) {
        if (_indiaStatesAndCities.containsKey(_stateController.text)) {
          _dropdownState = _stateController.text;
          _isCustomState = false;
        } else {
          _dropdownState = 'Other';
          _isCustomState = true;
        }
      }

      if (_cityController.text.isNotEmpty) {
        if (!_isCustomState &&
            _dropdownState != null &&
            _indiaStatesAndCities[_dropdownState] != null &&
            _indiaStatesAndCities[_dropdownState]!.contains(_cityController.text)) {
          _dropdownCity = _cityController.text;
          _isCustomCity = false;
        } else {
          _dropdownCity = 'Other';
          _isCustomCity = true;
        }
      }

      if (emp.dob != null && emp.dob!.isNotEmpty) {
        try {
          _selectedDob = DateTime.parse(emp.dob!);
          _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDob!);
        } catch (_) {}
      }
    } else {
      _selectedTeamId = widget.preFilledTeamId;
      _selectedRole = 'employee';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() {
        _pickedImage = image;
      });
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('photo_access_denied') || errMsg.contains('permission') || errMsg.contains('Permission')) {
          AppMessages.showError(
            context,
            'Gallery permission is required to choose a profile picture. Please enable in App Settings.',
          );
        } else {
          AppMessages.showError(context, 'Failed to pick image: $e');
        }
      }
    }
  }

  Future<void> _selectDob() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // At least 18 years old
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
        _selectedDob = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    final departmentText = _departmentController.text.trim();
    final isMarketing = departmentText.toLowerCase() == 'marketing';

    try {
      String? profilePictureUrl;

      // Upload picked image first if exists
      if (_pickedImage != null) {
        setState(() => _isUploadingPicture = true);
        try {
          final uploadResponse = await ApiService().uploadProfilePicture(
            _pickedImage!,
          );
          profilePictureUrl = uploadResponse['url'];
        } catch (e) {
          debugPrint('Profile picture upload error: $e');
        } finally {
          setState(() => _isUploadingPicture = false);
        }
      }

      if (_isEditMode && widget.employee != null) {
        final Map<String, dynamic> updateData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'employeeId': _employeeIdController.text.trim(),
          'department': departmentText,
          'role':
              _selectedRole, // designation/role is preserved or managed under-the-hood
          'workMode': _selectedWorkMode,
          'workType': isMarketing
              ? _getBackendWorkType(_selectedWorkType)
              : null,
          'state': _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          'city': _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          'dob': _selectedDob != null
              ? DateFormat('yyyy-MM-dd').format(_selectedDob!)
              : null,
          'teamId': _selectedTeamId,
        };

        if (profilePictureUrl != null) {
          updateData['profilePicture'] = profilePictureUrl;
        }

        if (_passwordController.text.isNotEmpty) {
          updateData['password'] = _passwordController.text;
        }

        await provider.updateEmployee(widget.employee!.id, updateData);
        if (mounted) {
          AppMessages.showSuccess(
            context,
            'Employee profile updated successfully.',
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new employee
        await provider.addEmployee(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _employeeIdController.text.trim(),
          departmentText,
          _passwordController.text,
          _selectedRole, // defaults to employee in backend if not selected otherwise
          dob: _selectedDob != null
              ? DateFormat('yyyy-MM-dd').format(_selectedDob!)
              : null,
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          workMode: _selectedWorkMode,
          workType: isMarketing ? _getBackendWorkType(_selectedWorkType) : null,
          profilePicture: profilePictureUrl,
          teamId: _selectedTeamId,
        );
        if (mounted) {
          AppMessages.showSuccess(
            context,
            'Employee registered and credentials emailed successfully.',
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBulkUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext sheetContext) {
        bool isLoading = false;
        String? errorMessage;
        Map<String, dynamic>? resultReport;
        PlatformFile? selectedFile;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> downloadTemplate() async {
              setSheetState(() { isLoading = true; errorMessage = null; });
              try {
                final bytes = await ApiService().downloadEmployeeTemplate();
                final tempDir = await getTemporaryDirectory();
                final tempFile = File('${tempDir.path}/employees_template.xlsx');
                await tempFile.writeAsBytes(bytes);
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(tempFile.path)],
                  text: 'HLAM – Bulk Employee Upload Template',
                ));
                setSheetState(() => isLoading = false);
              } catch (e) {
                setSheetState(() {
                  isLoading = false;
                  errorMessage = 'Download failed. Please check your connection.';
                });
              }
            }

            Future<void> pickFile() async {
              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xls', 'csv'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  setSheetState(() {
                    selectedFile = result.files.first;
                    errorMessage = null;
                    resultReport = null;
                  });
                }
              } catch (e) {
                setSheetState(() => errorMessage = 'Could not open file picker: $e');
              }
            }

            Future<void> uploadFile() async {
              if (selectedFile == null) {
                setSheetState(() => errorMessage = 'Please select a file first.');
                return;
              }
              final bytes = selectedFile!.bytes ??
                  (selectedFile!.path != null ? await File(selectedFile!.path!).readAsBytes() : null);
              if (bytes == null) {
                setSheetState(() => errorMessage = 'Could not read the file. Try again.');
                return;
              }
              setSheetState(() { isLoading = true; errorMessage = null; resultReport = null; });
              try {
                final report = await ApiService().bulkUploadEmployees(bytes, selectedFile!.name);
                setSheetState(() { isLoading = false; resultReport = report; selectedFile = null; });
                if ((report['insertedCount'] ?? 0) > 0 && ctx.mounted) {
                  Provider.of<AppProvider>(ctx, listen: false).fetchEmployees();
                }
              } catch (e) {
                setSheetState(() { isLoading = false; errorMessage = e.toString(); });
              }
            }

            final int inserted = resultReport?['insertedCount'] ?? 0;
            final int failed = resultReport?['failedCount'] ?? 0;
            final List errors = (resultReport?['errors'] as List?) ?? [];
            final bool hasResult = resultReport != null;

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gradient Header
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Bulk Employee Upload',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)),
                                          const SizedBox(height: 4),
                                          Text('Register multiple employees at once using an Excel sheet.',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, height: 1.4)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: isLoading ? null : () => Navigator.pop(sheetContext),
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              if (!hasResult) ...[
                                _buildBulkStepCard(step: '1', title: 'Download Template',
                                  subtitle: 'Get the official Excel template with all required columns.',
                                  icon: Icons.download_rounded, iconColor: const Color(0xFF0EA5E9), bgColor: const Color(0xFFEFF6FF),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2563EB),
                                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                      ),
                                      onPressed: isLoading ? null : downloadTemplate,
                                      icon: const Icon(Icons.download_rounded, size: 18),
                                      label: const Text('Download employees_template.xlsx',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _buildBulkStepCard(step: '2', title: 'Select Filled Spreadsheet',
                                  subtitle: 'Fill the template and pick the file from your device.',
                                  icon: Icons.folder_open_rounded, iconColor: const Color(0xFF8B5CF6), bgColor: const Color(0xFFF5F3FF),
                                  child: GestureDetector(
                                    onTap: isLoading ? null : pickFile,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: selectedFile != null ? const Color(0xFFEFF6FF) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selectedFile != null ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                          width: selectedFile != null ? 2 : 1.5,
                                        ),
                                      ),
                                      child: selectedFile == null
                                          ? Column(children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.upload_file_rounded, color: Color(0xFF8B5CF6), size: 28),
                                              ),
                                              const SizedBox(height: 10),
                                              const Text('Tap to browse files',
                                                style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 14)),
                                              const SizedBox(height: 4),
                                              const Text('.xlsx  •  .xls  •  .csv',
                                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                            ])
                                          : Row(children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.table_chart_rounded, color: Color(0xFF2563EB), size: 22),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text(selectedFile!.name,
                                                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis),
                                                Text('${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                              ])),
                                              GestureDetector(
                                                onTap: () => setSheetState(() { selectedFile = null; errorMessage = null; }),
                                                child: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 22),
                                              ),
                                            ]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                _buildBulkStepCard(step: '3', title: 'Register Employees',
                                  subtitle: 'Upload the spreadsheet to register all employees in your company.',
                                  icon: Icons.cloud_upload_rounded, iconColor: const Color(0xFF10B981), bgColor: const Color(0xFFECFDF5),
                                  child: Column(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: const Row(children: [
                                        Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 16),
                                        SizedBox(width: 8),
                                        Expanded(child: Text(
                                          'All employees will be assigned to your company automatically.',
                                          style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w500))),
                                      ]),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity, height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: selectedFile != null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                          foregroundColor: Colors.white,
                                          elevation: selectedFile != null ? 2 : 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: (selectedFile != null && !isLoading) ? uploadFile : null,
                                        icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                                        label: const Text('Upload & Register',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2)),
                                      ),
                                    ),
                                  ]),
                                ),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: inserted > 0
                                          ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                                          : [const Color(0xFF7F1D1D), const Color(0xFFEF4444)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (inserted > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                                        blurRadius: 16, offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(children: [
                                    Icon(inserted > 0 ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 48),
                                    const SizedBox(height: 10),
                                    Text(inserted > 0 ? 'Upload Complete!' : 'Upload Failed',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.3)),
                                    const SizedBox(height: 16),
                                    Row(children: [
                                      Expanded(child: _buildBulkStatPill(value: '$inserted', label: 'Registered',
                                        icon: Icons.person_add_rounded, color: Colors.white)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildBulkStatPill(value: '$failed', label: 'Failed',
                                        icon: Icons.person_remove_rounded, color: Colors.white.withValues(alpha: 0.85))),
                                    ]),
                                  ]),
                                ),
                                const SizedBox(height: 16),

                                if (errors.isNotEmpty) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                                        child: Row(children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                                          ),
                                          const SizedBox(width: 10),
                                          Text('${errors.length} Row${errors.length > 1 ? 's' : ''} Had Issues',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626), fontSize: 14)),
                                        ]),
                                      ),
                                      const Divider(height: 1, color: Color(0xFFFECACA)),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.all(12),
                                        itemCount: errors.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                                        itemBuilder: (_, i) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8)),
                                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const Padding(padding: EdgeInsets.only(top: 2),
                                              child: Icon(Icons.circle, size: 6, color: Color(0xFFEF4444))),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(errors[i].toString(),
                                              style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 12, height: 1.4))),
                                          ]),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                Row(children: [
                                  Expanded(child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFF2563EB)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                    ),
                                    onPressed: () => setSheetState(() { resultReport = null; selectedFile = null; errorMessage = null; }),
                                    icon: const Icon(Icons.upload_rounded, size: 18),
                                    label: const Text('Upload Another', style: TextStyle(fontWeight: FontWeight.w700)),
                                  )),
                                  const SizedBox(width: 12),
                                  Expanded(child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                    ),
                                    onPressed: () => Navigator.pop(sheetContext),
                                    icon: const Icon(Icons.done_rounded, size: 18),
                                    label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                                  )),
                                ]),
                              ],

                              if (isLoading) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Column(children: [
                                    const SizedBox(
                                      width: 48, height: 48,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)), strokeWidth: 3),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Processing...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 6),
                                    Text(
                                      selectedFile != null ? 'Validating and registering employees from ${selectedFile!.name}' : 'Please wait...',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
                                  ]),
                                ),
                              ],

                              if (errorMessage != null && !isLoading) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(errorMessage!,
                                      style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500))),
                                  ]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBulkStepCard({
    required String step,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('STEP $step',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.8)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 14))),
              ]),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4)),
            ])),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
      ]),
    );
  }

  Widget _buildBulkStatPill({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {

    final teams = Provider.of<AppProvider>(context).teams;
    final title = _isEditMode ? 'Edit Profile' : 'Register Employee';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading || _isUploadingPicture
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Heading
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isEditMode ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEditMode ? 'Update Employee Record' : 'Add New Colleague',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isEditMode
                                      ? 'Modify employee details, job configurations, or state parameters.'
                                      : 'Register a single employee profile. Credentials will be sent via email.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bulk Upload Quick-Action Card (Add mode only)
                    if (!_isEditMode)
                      GestureDetector(
                        onTap: () => _showBulkUploadSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bulk Upload Employees',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Register multiple employees at once via Excel sheet',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Use Excel',
                                  style: TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                            ],
                          ),
                        ),
                      ),

                    if (!_isEditMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR ADD MANUALLY',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                          ],
                        ),
                      ),

                    if (_isEditMode) const SizedBox(height: 24),

                    // Avatar Picker Header
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundColor: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.08),
                            backgroundImage: _pickedImage != null
                                ? FileImage(File(_pickedImage!.path))
                                : (_isEditMode &&
                                          widget.employee?.profilePicture !=
                                              null &&
                                          widget
                                              .employee!
                                              .profilePicture!
                                              .isNotEmpty
                                      ? NetworkImage(
                                              '${ApiService.baseUrl.replaceAll('/api', '')}${widget.employee!.profilePicture}',
                                            )
                                            as ImageProvider
                                      : null),
                            onBackgroundImageError: _pickedImage != null || (_isEditMode &&
                                          widget.employee?.profilePicture !=
                                              null &&
                                          widget
                                              .employee!
                                              .profilePicture!
                                              .isNotEmpty)
                                ? (exception, stackTrace) {
                                    debugPrint('Error loading profile image: $exception');
                                  }
                                : null,
                            child:
                                _pickedImage == null &&
                                    (!_isEditMode ||
                                        widget.employee?.profilePicture ==
                                            null ||
                                        widget
                                            .employee!
                                            .profilePicture!
                                            .isEmpty)
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 54,
                                    color: Color(0xFF2563EB),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF2563EB),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category 1: Personal Profile
                    _buildSectionHeader('PERSONAL PROFILE'),
                    _buildCategoryCard([
                      // Full Name
                      Row(
                        children: [
                          const Text(
                            'FULL NAME',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Name is required'
                            : null,
                        decoration: _inputDecoration(
                          hint: 'John Doe',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email
                      Row(
                        children: [
                          const Text(
                            'EMAIL ADDRESS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(val.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: 'john.doe@company.com',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password
                      Row(
                        children: [
                          Text(
                            _isEditMode ? 'NEW PASSWORD (OPTIONAL)' : 'PASSWORD',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (!_isEditMode) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '*',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: (val) {
                          if (!_isEditMode && (val == null || val.isEmpty)) {
                            return 'Password is required for registration';
                          }
                          if (val != null && val.isNotEmpty && val.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: _isEditMode
                              ? 'Leave blank to keep current'
                              : '••••••',
                          icon: Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date of Birth
                      const Text(
                        'DATE OF BIRTH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _selectDob,
                        decoration: _inputDecoration(
                          hint: 'YYYY-MM-DD',
                          icon: Icons.cake_outlined,
                          suffix: const Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Category 2: Location & Residence
                    _buildSectionHeader('LOCATION & RESIDENCE'),
                    _buildCategoryCard([
                      // State Dropdown
                      const Text(
                        'STATE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _dropdownState,
                        decoration: _dropdownDecoration(
                          icon: Icons.map_outlined,
                        ),
                        hint: const Text(
                          'Select State',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        items: _indiaStatesAndCities.keys.map((state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(
                              state,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _dropdownState = val;
                            if (val == 'Other') {
                              _isCustomState = true;
                              _stateController.clear();
                              // Reset city too
                              _dropdownCity = null;
                              _isCustomCity = false;
                              _cityController.clear();
                            } else {
                              _isCustomState = false;
                              _stateController.text = val ?? '';
                              // Reset city dropdown selection
                              _dropdownCity = null;
                              _isCustomCity = false;
                              _cityController.clear();
                            }
                          });
                        },
                      ),
                      if (_isCustomState) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _stateController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            hint: 'Enter State Name *',
                            icon: Icons.edit_location_alt_outlined,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'State name is required'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // City Dropdown
                      const Text(
                        'CITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _dropdownCity,
                        decoration: _dropdownDecoration(
                          icon: Icons.location_city_outlined,
                        ),
                        hint: Text(
                          _dropdownState == null
                              ? 'Select State First'
                              : 'Select City',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        items: _dropdownState == null
                            ? []
                            : (_indiaStatesAndCities[_dropdownState] ?? ['Other']).map((city) {
                                return DropdownMenuItem<String>(
                                  value: city,
                                  child: Text(
                                    city,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                );
                              }).toList(),
                        onChanged: _dropdownState == null
                            ? null
                            : (val) {
                                setState(() {
                                  _dropdownCity = val;
                                  if (val == 'Other') {
                                    _isCustomCity = true;
                                    _cityController.clear();
                                  } else {
                                    _isCustomCity = false;
                                    _cityController.text = val ?? '';
                                  }
                                });
                              },
                      ),
                      if (_isCustomCity) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cityController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            hint: 'Enter City Name *',
                            icon: Icons.edit_location_outlined,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'City name is required'
                              : null,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),

                    // Category 3: Professional & Environment
                    _buildSectionHeader('PROFESSIONAL & ENVIRONMENT'),
                    _buildCategoryCard([
                      // Role Field
                      const Text(
                        'ROLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _getAvailableRoles().length > 1
                          ? DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedRole,
                              decoration: _dropdownDecoration(
                                icon: Icons.person_pin_outlined,
                              ),
                              items: _getAvailableRoles().map((role) {
                                String displayRole = role;
                                if (role == 'manager') displayRole = 'Manager';
                                if (role == 'team_leader') displayRole = 'Team Leader';
                                if (role == 'employee') displayRole = 'Employee';
                                return DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(
                                    displayRole,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRole = val;
                                  });
                                }
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedRole == 'manager'
                                        ? 'Manager'
                                        : (_selectedRole == 'team_leader' ? 'Team Leader' : 'Employee'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'LOCKED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 20),

                      // Employee ID
                      Row(
                        children: [
                          const Text(
                            'EMPLOYEE ID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _employeeIdController,
                        textCapitalization: TextCapitalization.characters,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Employee ID is required'
                            : null,
                        decoration: _inputDecoration(
                          hint: 'EMP1024',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Department
                      Row(
                        children: [
                          const Text(
                            'DEPARTMENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDepartment,
                        decoration: _dropdownDecoration(
                          icon: Icons.business_outlined,
                        ),
                        hint: const Text(
                          'Select Department',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Department is required'
                            : null,
                        items: _getDepartmentDropdownItems(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDepartment = val;
                            _departmentController.text = val ?? '';
                            if (val?.toLowerCase() == 'marketing') {
                              _selectedWorkType ??= 'Office Work';
                            } else {
                              _selectedWorkType = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Assign Team
                      const Text(
                        'ASSIGN TO TEAM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedTeamId,
                        decoration: _dropdownDecoration(
                          icon: Icons.groups_outlined,
                        ),
                        hint: const Text(
                          'No Team (Unassigned)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'No Team (Unassigned)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          ...teams.map((team) {
                            return DropdownMenuItem<int?>(
                              value: team['id'],
                              child: Text(
                                team['name'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedTeamId = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Marketing Work Type (Conditionally Shown)
                      if (_departmentController.text.trim().toLowerCase() ==
                          'marketing') ...[
                        Row(
                          children: [
                            const Text(
                              'WORK TYPE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '*',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedWorkType ?? 'Office Work',
                          decoration: _dropdownDecoration(
                            icon: Icons.directions_run_outlined,
                          ),
                          items: _workTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedWorkType = val;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Work Mode (Hidden for Marketing employees with Field Work or Office+Field work)
                      if (!(_departmentController.text.trim().toLowerCase() ==
                              'marketing' &&
                          (_selectedWorkType == 'Field Work' ||
                              _selectedWorkType == 'Office+Field work' ||
                              _selectedWorkType == 'Office + Field Work'))) ...[
                        const Text(
                          'WORK MODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedWorkMode,
                          decoration: _dropdownDecoration(
                            icon: Icons.location_on_outlined,
                          ),
                          items: _workModes.map((mode) {
                            return DropdownMenuItem<String>(
                              value: mode,
                              child: Text(
                                mode,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedWorkMode = val);
                            }
                          },
                        ),
                      ],
                    ]),
                    const SizedBox(height: 36),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shadowColor: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.3),
                          elevation: 6,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isEditMode
                              ? 'Save Profile Changes'
                              : 'Register New Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      suffixIcon: suffix,
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  InputDecoration _dropdownDecoration({required IconData icon}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }
}
