import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/app_provider.dart';
import '../utils/app_messages.dart';
import 'shift_management_screen.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _checkInController;
  late TextEditingController _checkOutController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _addressController;
  late TextEditingController _radiusController;
  late TextEditingController _monthlyPaidLeavesController;
  late TextEditingController _yearlyPaidLeavesController;

  int? _selectedRefreshMonth;
  int? _selectedRefreshDay;

  bool _loadingSettings = true;
  bool _fetchingLocation = false;
  bool _savingSettings = false;

  TimeOfDay? _selectedCheckInTime;
  TimeOfDay? _selectedCheckOutTime;

  @override
  void initState() {
    super.initState();
    _checkInController = TextEditingController();
    _checkOutController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _addressController = TextEditingController();
    _radiusController = TextEditingController();
    _monthlyPaidLeavesController = TextEditingController();
    _yearlyPaidLeavesController = TextEditingController();

    _selectedRefreshMonth = 1;
    _selectedRefreshDay = 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanySettings();
    });
  }

  @override
  void dispose() {
    _checkInController.dispose();
    _checkOutController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    _monthlyPaidLeavesController.dispose();
    _yearlyPaidLeavesController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanySettings() async {
    setState(() => _loadingSettings = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await Future.wait([
        provider.fetchCompanySettings(),
        provider.fetchShifts(),
      ]);
      
      // Populate fields from provider
      if (provider.checkInTime != null) {
        _checkInController.text = provider.checkInTime!;
        _selectedCheckInTime = _parseTimeString(provider.checkInTime!);
      }
      if (provider.checkOutTime != null) {
        _checkOutController.text = provider.checkOutTime!;
        _selectedCheckOutTime = _parseTimeString(provider.checkOutTime!);
      }
      _latController.text = provider.officeLatitude?.toString() ?? '0.0';
      _lngController.text = provider.officeLongitude?.toString() ?? '0.0';
      _addressController.text = provider.officeAddress ?? '';
      _radiusController.text = provider.geofencingRadius?.toString() ?? '100.0';
      
      _monthlyPaidLeavesController.text = provider.monthlyPaidLeaves?.toString() ?? '0';
      _yearlyPaidLeavesController.text = provider.yearlyPaidLeaves?.toString() ?? '0';
      
      setState(() {
        _selectedRefreshMonth = provider.leavesRefreshMonth ?? 1;
        _selectedRefreshDay = provider.leavesRefreshDay ?? 1;
      });
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to load settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSettings = false);
      }
    }
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<void> _selectTime(BuildContext context, bool isCheckIn) async {
    final initialTime = isCheckIn 
        ? (_selectedCheckInTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_selectedCheckOutTime ?? const TimeOfDay(hour: 18, minute: 0));
        
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
        if (isCheckIn) {
          _selectedCheckInTime = picked;
          _checkInController.text = _formatTimeOfDay(picked);
        } else {
          _selectedCheckOutTime = picked;
          _checkOutController.text = _formatTimeOfDay(picked);
        }
      });
    }
  }

  Future<void> _fetchCurrentLiveLocation() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _fetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on your device.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, please enable in settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latController.text = position.latitude.toString();
      _lngController.text = position.longitude.toString();

      try {
        await setLocaleIdentifier("en_US");
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 10));

        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          final street = place.street ?? '';
          final locality = place.locality ?? '';
          final subLocality = place.subLocality ?? '';
          final city = place.subAdministrativeArea ?? place.administrativeArea ?? '';
          final country = place.country ?? '';
          final postal = place.postalCode ?? '';
          
          final formatted = [street, subLocality, locality, city, postal, country]
              .where((s) => s.isNotEmpty)
              .join(', ');
              
          _addressController.text = await provider.getCleanEnglishAddress(position.latitude, position.longitude, formatted);
        } else {
          _addressController.text = 'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
        }
      } catch (geocodeError) {
        _addressController.text = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        debugPrint('Geocoding failed: $geocodeError');
      }

      if (mounted) {
        AppMessages.showSuccess(context, 'Successfully locked current live location!');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _savingSettings = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.updateCompanySettings(
        checkInTime: _checkInController.text,
        checkOutTime: _checkOutController.text,
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_lngController.text),
        address: _addressController.text.trim(),
        radius: double.tryParse(_radiusController.text),
        monthlyPaidLeaves: int.tryParse(_monthlyPaidLeavesController.text),
        yearlyPaidLeaves: int.tryParse(_yearlyPaidLeavesController.text),
        leavesRefreshMonth: _selectedRefreshMonth,
        leavesRefreshDay: _selectedRefreshDay,
      );

      if (mounted) {
        AppMessages.showSuccess(context, 'Company settings saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Failed to save settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _savingSettings = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Company Configuration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Schedule Section
                      _buildSectionHeader(Icons.schedule_rounded, 'Company Schedules'),
                      const SizedBox(height: 12),
                      _buildScheduleCard(),
                      
                      const SizedBox(height: 24),
                      
                      // Geofencing and Coordinates Section
                      _buildSectionHeader(Icons.my_location_rounded, 'Geofencing Settings'),
                      const SizedBox(height: 12),
                      _buildLocationCard(),

                      const SizedBox(height: 24),

                      // Leaves Policy Section
                      _buildSectionHeader(Icons.event_note_rounded, 'Leaves Policy Settings'),
                      const SizedBox(height: 12),
                      _buildLeavesPolicyCard(),
                      
                      const SizedBox(height: 24),

                      // Shift Configuration Section
                      _buildSectionHeader(Icons.pending_actions_rounded, 'Shift Management'),
                      const SizedBox(height: 12),
                      _buildShiftsCard(),

                      const SizedBox(height: 32),
                      
                      // Action buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTimePickerField(
                  label: 'Check-In Time',
                  controller: _checkInController,
                  icon: Icons.login_rounded,
                  onTap: () => _selectTime(context, true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePickerField(
                  label: 'Check-Out Time',
                  controller: _checkOutController,
                  icon: Icons.logout_rounded,
                  onTap: () => _selectTime(context, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The daily check-in and check-out schedule for location tracking and attendance late flags.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _fetchingLocation ? null : _fetchCurrentLiveLocation,
              icon: _fetchingLocation 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_rounded, color: Colors.white),
              label: Text(
                _fetchingLocation ? 'Acquiring GPS...' : 'Save Live Company Location',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Latitude',
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid float';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Longitude',
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid float';
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            label: 'Office Street Address',
            controller: _addressController,
            maxLines: 2,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Address is required';
              if (v.length > 255) return 'Maximum 255 characters';
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            label: 'Geofence Radius (meters)',
            controller: _radiusController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.radar_rounded,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Invalid radius';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeavesPolicyCard() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Monthly Paid Leaves',
                  controller: _monthlyPaidLeavesController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Invalid integer';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Yearly Paid Leaves Limit',
                  controller: _yearlyPaidLeavesController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Invalid integer';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Leaves Refresh Anniversary Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedRefreshMonth,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(months[index]),
                        );
                      }),
                      onChanged: (val) {
                        setState(() {
                          _selectedRefreshMonth = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedRefreshDay,
                      items: List.generate(31, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('Day ${index + 1}'),
                        );
                      }),
                      onChanged: (val) {
                        setState(() {
                          _selectedRefreshDay = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Employees\' carryover leaves reset to 0 and refresh starting from this month and day every year.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsCard() {
    final provider = Provider.of<AppProvider>(context);
    final shiftCount = provider.shifts.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF4F46E5),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shift Configurations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$shiftCount active shift${shiftCount == 1 ? '' : 's'} configured',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Configure daily shift timings (e.g. morning, night, custom rotations) and assign default shifts to employees to calculate accurate Late In / Early Out status and working hours.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
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
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ShiftManagementScreen()),
                ).then((_) => _loadCompanySettings()); // reload to refresh active count
              },
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Manage Shifts & Assignments',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF2563EB), size: 20) : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
      validator: validator,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _savingSettings ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _savingSettings
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Save Configuration',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Discard Changes',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
