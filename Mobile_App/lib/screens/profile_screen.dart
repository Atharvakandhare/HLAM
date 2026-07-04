import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime? _selectedDob;
  String? _dropdownState;
  String? _dropdownCity;
  bool _isCustomState = false;
  bool _isCustomCity = false;

  static const Map<String, List<String>> _indiaStatesAndCities = {
    'Andhra Pradesh': [
      'Visakhapatnam',
      'Vijayawada',
      'Guntur',
      'Nellore',
      'Tirupati',
      'Kurnool',
      'Other',
    ],
    'Arunachal Pradesh': [
      'Itanagar',
      'Naharlagun',
      'Tawang',
      'Pasighat',
      'Other',
    ],
    'Assam': ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Nagaon', 'Other'],
    'Bihar': [
      'Patna',
      'Gaya',
      'Bhagalpur',
      'Muzaffarpur',
      'Darbhanga',
      'Other',
    ],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg', 'Other'],
    'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Other'],
    'Gujarat': [
      'Ahmedabad',
      'Surat',
      'Vadodara',
      'Rajkot',
      'Bhavnagar',
      'Jamnagar',
      'Other',
    ],
    'Haryana': [
      'Faridabad',
      'Gurugram',
      'Panipat',
      'Ambala',
      'Yamunanagar',
      'Other',
    ],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Other'],
    'Jharkhand': [
      'Ranchi',
      'Jamshedpur',
      'Dhanbad',
      'Bokaro Steel City',
      'Other',
    ],
    'Karnataka': [
      'Bengaluru',
      'Mysuru',
      'Hubballi-Dharwad',
      'Mangaluru',
      'Belagavi',
      'Other',
    ],
    'Kerala': [
      'Thiruvananthapuram',
      'Kochi',
      'Kozhikode',
      'Thrissur',
      'Kollam',
      'Other',
    ],
    'Madhya Pradesh': [
      'Indore',
      'Bhopal',
      'Jabalpur',
      'Gwalior',
      'Ujjain',
      'Other',
    ],
    'Maharashtra': [
      'Mumbai',
      'Pune',
      'Nagpur',
      'Thane',
      'Nashik',
      'Aurangabad',
      'Solapur',
      'Other',
    ],
    'Manipur': ['Imphal', 'Thoubal', 'Bishnupur', 'Other'],
    'Meghalaya': ['Shillong', 'Tura', 'Jowai', 'Other'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Champhai', 'Other'],
    'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Other'],
    'Odisha': [
      'Bhubaneswar',
      'Cuttack',
      'Rourkela',
      'Sambalpur',
      'Puri',
      'Other',
    ],
    'Punjab': [
      'Ludhiana',
      'Amritsar',
      'Jalandhar',
      'Patiala',
      'Bathinda',
      'Other',
    ],
    'Rajasthan': [
      'Jaipur',
      'Jodhpur',
      'Kota',
      'Bikaner',
      'Ajmer',
      'Udaipur',
      'Other',
    ],
    'Sikkim': ['Gangtok', 'Namchi', 'Geyzing', 'Other'],
    'Tamil Nadu': [
      'Chennai',
      'Coimbatore',
      'Madurai',
      'Tiruchirappalli',
      'Salem',
      'Tirunelveli',
      'Other',
    ],
    'Telangana': [
      'Hyderabad',
      'Warangal',
      'Nizamabad',
      'Khammam',
      'Karimnagar',
      'Other',
    ],
    'Tripura': ['Agartala', 'Dharmanagar', 'Udaipur', 'Other'],
    'Uttar Pradesh': [
      'Lucknow',
      'Kanpur',
      'Ghaziabad',
      'Agra',
      'Varanasi',
      'Meerut',
      'Noida',
      'Prayagraj',
      'Other',
    ],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Haldwani', 'Roorkee', 'Other'],
    'West Bengal': [
      'Kolkata',
      'Howrah',
      'Asansol',
      'Siliguri',
      'Durgapur',
      'Other',
    ],
    'Andaman and Nicobar Islands': ['Port Blair', 'Other'],
    'Chandigarh': ['Chandigarh', 'Other'],
    'Dadra and Nagar Haveli and Daman and Diu': [
      'Daman',
      'Diu',
      'Silvassa',
      'Other',
    ],
    'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Other'],
    'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Other'],
    'Ladakh': ['Leh', 'Kargil', 'Other'],
    'Lakshadweep': ['Kavaratti', 'Other'],
    'Puducherry': ['Puducherry', 'Karaikal', 'Other'],
    'Other': ['Other'],
  };

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _showEditProfileSheet() {
    if (_user == null) return;

    _nameController.text = _user!.name;
    _stateController.text = _user!.state ?? '';
    _cityController.text = _user!.city ?? '';

    if (_user!.dob != null && _user!.dob!.isNotEmpty) {
      try {
        _selectedDob = DateTime.parse(_user!.dob!);
        _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDob!);
      } catch (_) {
        _dobController.text = _user!.dob!;
      }
    } else {
      _selectedDob = null;
      _dobController.clear();
    }

    if (_stateController.text.isNotEmpty) {
      if (_indiaStatesAndCities.containsKey(_stateController.text)) {
        _dropdownState = _stateController.text;
        _isCustomState = false;
      } else {
        _dropdownState = 'Other';
        _isCustomState = true;
      }
    } else {
      _dropdownState = null;
      _isCustomState = false;
    }

    if (_cityController.text.isNotEmpty) {
      if (!_isCustomState &&
          _dropdownState != null &&
          _indiaStatesAndCities[_dropdownState] != null &&
          _indiaStatesAndCities[_dropdownState]!.contains(
            _cityController.text,
          )) {
        _dropdownCity = _cityController.text;
        _isCustomCity = false;
      } else {
        _dropdownCity = 'Other';
        _isCustomCity = true;
      }
    } else {
      _dropdownCity = null;
      _isCustomCity = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> selectDob() async {
            final DateTime? picked = await showDatePicker(
              context: sheetCtx,
              initialDate: _selectedDob ?? DateTime(1995, 1, 1),
              firstDate: DateTime(1950),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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
              setSheetState(() {
                _selectedDob = picked;
                _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            }
          }

          InputDecoration inputDecoration(String hint, IconData icon) {
            return InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            );
          }

          InputDecoration dropdownDecoration(IconData icon) {
            return InputDecoration(
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            );
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Edit Profile Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(sheetCtx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Editable: Full Name
                            const Text(
                              'FULL NAME',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Name is required'
                                  : null,
                              decoration: inputDecoration(
                                'Full Name',
                                Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Editable: Date of Birth
                            const Text(
                              'DATE OF BIRTH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _dobController,
                              readOnly: true,
                              onTap: selectDob,
                              decoration:
                                  inputDecoration(
                                    'YYYY-MM-DD',
                                    Icons.cake_outlined,
                                  ).copyWith(
                                    suffixIcon: const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 16),

                            // Editable: State
                            const Text(
                              'STATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _dropdownState,
                              decoration: dropdownDecoration(
                                Icons.map_outlined,
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
                                setSheetState(() {
                                  _dropdownState = val;
                                  if (val == 'Other') {
                                    _isCustomState = true;
                                    _stateController.clear();
                                    _dropdownCity = null;
                                    _isCustomCity = false;
                                    _cityController.clear();
                                  } else {
                                    _isCustomState = false;
                                    _stateController.text = val ?? '';
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
                                decoration: inputDecoration(
                                  'Enter State Name *',
                                  Icons.edit_location_alt_outlined,
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'State name is required'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Editable: City
                            const Text(
                              'CITY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_dropdownState),
                              isExpanded: true,
                              initialValue: _dropdownCity,
                              decoration: dropdownDecoration(
                                Icons.location_city_outlined,
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
                                  : (_indiaStatesAndCities[_dropdownState] ??
                                            ['Other'])
                                        .map((city) {
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
                                        })
                                        .toList(),
                              onChanged: _dropdownState == null
                                  ? null
                                  : (val) {
                                      setSheetState(() {
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
                                decoration: inputDecoration(
                                  'Enter City Name *',
                                  Icons.edit_location_outlined,
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'City name is required'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 24),

                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 20),

                            // LOCKED/READ-ONLY SECTION
                            const Text(
                              'LOCKED PROFILE INFORMATION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Email Address (Locked)
                            _buildLockedField(
                              label: 'EMAIL ADDRESS',
                              value: _user!.email,
                              icon: Icons.email_outlined,
                            ),
                            const SizedBox(height: 12),

                            // Role (Locked)
                            _buildLockedField(
                              label: 'ROLE / DESIGNATION',
                              value: _user!.role.toUpperCase().replaceAll(
                                '_',
                                ' ',
                              ),
                              icon: Icons.badge_outlined,
                            ),
                            if (_user!.employeeId != null &&
                                _user!.employeeId!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              // Employee ID (Locked)
                              _buildLockedField(
                                label: 'EMPLOYEE ID',
                                value: _user!.employeeId!,
                                icon: Icons.assignment_ind_outlined,
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Save changes button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }

                                  Navigator.pop(sheetCtx); // Close sheet
                                  setState(() => _loading = true);

                                  try {
                                    await ApiService().updateProfile(
                                      name: _nameController.text.trim(),
                                      dob: _dobController.text.trim().isEmpty
                                          ? null
                                          : _dobController.text.trim(),
                                      state:
                                          _stateController.text.trim().isEmpty
                                          ? null
                                          : _stateController.text.trim(),
                                      city: _cityController.text.trim().isEmpty
                                          ? null
                                          : _cityController.text.trim(),
                                    );

                                    // Refresh local user info
                                    await _loadUser();

                                    if (mounted) {
                                      AppMessages.showSuccess(
                                        context,
                                        'Profile details updated successfully.',
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      AppMessages.showError(
                                        context,
                                        e.toString(),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _loading = false);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Save Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLockedField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
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
    if (_user?.isProfilePictureAdminSet == true) {
      if (mounted) {
        AppMessages.showError(
          context,
          'Your profile picture has been locked by the administrator.',
        );
      }
      return;
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
          AppMessages.showSuccess(
            context,
            'Profile picture updated successfully.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('photo_access_denied') ||
            errMsg.contains('permission') ||
            errMsg.contains('Permission')) {
          AppMessages.showError(
            context,
            'Gallery permission is required to choose a profile picture. Please enable it in Settings.',
          );
        } else {
          if (errMsg.contains('EACCES')) {
            errMsg =
                'Server directory write permission denied (EACCES). Please ask your server administrator to grant write permissions (chmod 775) to the backend uploads/ folder.';
          }
          AppMessages.showError(
            context,
            'Failed to upload profile picture: $errMsg',
          );
        }
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
      AppMessages.showError(
        context,
        'Your profile picture has been locked by the administrator.',
      );
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Old Password
                const Text(
                  'CURRENT PASSWORD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: oldPasswordCtrl,
                  obscureText: obscureOld,
                  validator: (val) => val == null || val.isEmpty
                      ? 'Current password is required'
                      : null,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureOld ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () =>
                          setSheetState(() => obscureOld = !obscureOld),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // New Password
                const Text(
                  'NEW PASSWORD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'New password is required';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••',
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () =>
                          setSheetState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm New Password
                const Text(
                  'CONFIRM NEW PASSWORD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureConfirm,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Confirm password is required';
                    }
                    if (val != newPasswordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••',
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () =>
                          setSheetState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                        final provider = Provider.of<AppProvider>(
                          context,
                          listen: false,
                        );
                        await provider.changePassword(
                          oldPasswordCtrl.text,
                          newPasswordCtrl.text,
                        );
                        if (mounted) {
                          AppMessages.showSuccess(
                            context,
                            'Password changed successfully.',
                          );
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Update Password',
                      style: TextStyle(
                        color: Colors.white,
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
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF4444),
          ),
        ),
        content: const Text(
          'Are you sure you want to log out from the application?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    final emp = _user!;
    final bool isAdmin =
        emp.role == 'system_admin' || emp.role == 'company_admin';

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          top: false, // Allow background header gradient to cover status bar space
          bottom: true, // Respect bottom navigation safe area bar
          child: Column(
            children: [
              _buildStickyHeader(emp),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      if (isAdmin) ...[
                        // For system_admin and company_admin
                        _buildSectionHeader('ADMINISTRATOR INFORMATION'),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.person_outline_rounded,
                            'Name',
                            emp.name,
                            isEditable: true,
                            themeColor: const Color(0xFF2563EB),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email Address',
                            emp.email,
                            themeColor: const Color(0xFF2563EB),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.badge_outlined,
                            'Role / Designation',
                            emp.role.toUpperCase().replaceAll('_', ' '),
                            themeColor: const Color(0xFF2563EB),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        _buildSectionHeader('COMPANY INFORMATION'),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.business_outlined,
                            'Company Name',
                            emp.companyName ?? 'N/A',
                            themeColor: const Color(0xFF10B981),
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ] else ...[
                        // For employees, managers, team leaders
                        _buildSectionHeader('EMPLOYEE INFORMATION'),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.person_outline_rounded,
                            'Name',
                            emp.name,
                            isEditable: true,
                            themeColor: const Color(0xFF2563EB),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.badge_outlined,
                            'Employee ID',
                            emp.employeeId ?? 'N/A',
                            themeColor: const Color(0xFF2563EB),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.business_outlined,
                            'Department',
                            emp.department ?? 'N/A',
                            themeColor: const Color(0xFF2563EB),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email Address',
                            emp.email,
                            themeColor: const Color(0xFF2563EB),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.cake_outlined,
                            'Date of Birth',
                            formattedDob,
                            isEditable: true,
                            themeColor: const Color(0xFF2563EB),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        _buildSectionHeader('TEAM ASSIGNMENTS'),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.business_outlined,
                            'Company Name',
                            emp.companyName ?? 'N/A',
                            themeColor: const Color(0xFF10B981),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.groups_outlined,
                            'Assigned Team Name',
                            emp.teamName ?? 'N/A',
                            themeColor: const Color(0xFF10B981),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.person_pin_outlined,
                            'Team Manager Name',
                            emp.managerName ?? 'N/A',
                            themeColor: const Color(0xFF10B981),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.assignment_ind_outlined,
                            'Team Leader Name',
                            emp.teamLeaderName ?? 'N/A',
                            themeColor: const Color(0xFF10B981),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        _buildSectionHeader('WORK ENVIRONMENT'),
                        _buildInfoCard([
                          if (!(emp.department?.toLowerCase() == 'marketing' &&
                              (emp.workType == 'Field Work' ||
                                  emp.workType == 'Office + Field Work'))) ...[
                            _buildInfoRow(
                              Icons.location_on_outlined,
                              'Work Mode',
                              emp.workMode ?? 'Work From Office',
                              themeColor: const Color(0xFFF59E0B),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                            ),
                          ],
                          _buildInfoRow(
                            Icons.work_outline_rounded,
                            'Work Type',
                            emp.workType ?? 'N/A',
                            themeColor: const Color(0xFFF59E0B),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.map_outlined,
                            'State',
                            emp.state ?? 'N/A',
                            isEditable: true,
                            themeColor: const Color(0xFFF59E0B),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            Icons.location_city_outlined,
                            'City',
                            emp.city ?? 'N/A',
                            isEditable: true,
                            themeColor: const Color(0xFFF59E0B),
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],

                      _buildSectionHeader('ACCOUNT SECURITY'),
                      _buildInfoCard([
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            'Update Account Password',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: const Text(
                            'Keep your login secure and up to date.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: _showChangePasswordSheet,
                        ),
                        if (isAdmin) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.settings_suggest_rounded,
                                color: Color(0xFF10B981),
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              'Configure Company Rules',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: const Text(
                              'Update GPS geofence, times, and radius.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CompanySettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader(User emp) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double headerHeight = 155 + statusBarHeight;
    final double cardTop = headerHeight - 85;
    final double totalHeight = cardTop + 235;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 1. Gradient Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A), // Deep Navy Blue
                    Color(0xFF3B82F6), // Vibrant Royal Blue
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  // Subtle ambient background circles
                  Positioned(
                    right: -40,
                    top: -40,
                    child: CircleAvatar(
                      radius: 90,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -20,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  // "My Profile" title and logout button
                  Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: statusBarHeight + 8,
                      bottom: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          tooltip: 'Log Out',
                          onPressed: _confirmLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 2. Profile Card
          Positioned(
            top: cardTop,
            left: 0,
            right: 0,
            child: _buildProfileCard(emp),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User emp) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar Section with Gradient border
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _isUploadingPicture
                      ? const CircleAvatar(
                          radius: 50,
                          backgroundColor: Color(0xFFF8FAFC),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : AppAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          imageUrl: emp.profilePicture != null && emp.profilePicture!.isNotEmpty
                              ? '${ApiService.baseUrl.replaceAll('/api', '')}${emp.profilePicture}'
                              : null,
                          fallback: Text(
                            emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 36,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name & Role
          Text(
            emp.name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF2563EB),
                  size: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  emp.role.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (emp.profilePicture != null && emp.profilePicture!.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _deleteImage,
              child: const Text(
                'Remove Photo',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 28, top: 20, bottom: 4),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isEditable = false,
    Color themeColor = const Color(0xFF2563EB),
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: isEditable ? _showEditProfileSheet : null,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: themeColor, size: 20),
        ),
        title: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontSize: 14.5,
            ),
          ),
        ),
        trailing: isEditable
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: themeColor,
                  size: 14,
                ),
              )
            : null,
      ),
    );
  }
}
