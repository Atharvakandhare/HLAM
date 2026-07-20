import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AdminMarketingTrackingScreen extends StatefulWidget {
  const AdminMarketingTrackingScreen({super.key});

  @override
  State<AdminMarketingTrackingScreen> createState() => _AdminMarketingTrackingScreenState();
}

class _AdminMarketingTrackingScreenState extends State<AdminMarketingTrackingScreen> {
  User? _currentUser;
  bool _isLoading = true;
  dynamic _selectedEmployeeData; // Selected employee's map data
  DateTime _selectedDate = DateTime.now();
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  // Fallback Center coordinates (Shoreline Park / Mountain View matching the screenshot!)
  static const double _fallbackLat = 37.4300;
  static const double _fallbackLng = -122.0800;

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
    await provider.fetchAllMarketingEmployees();

    final allMarketing = provider.allMarketingEmployees;
    if (allMarketing.isNotEmpty) {
      _selectedEmployeeData = allMarketing.first;
      await _fetchTrailForSelected();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTrailForSelected() async {
    if (_selectedEmployeeData == null) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final int userId = _selectedEmployeeData['user']['id'];
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    await provider.fetchMarketingTrail(userId, date: dateStr);
    
    // Auto-center map if coordinates exist and map is ready
    final coords = _getSelectedEmployeeCoords();
    if (coords != null && _isMapReady) {
      try {
        _mapController.move(coords, 14.5);
      } catch (e) {
        debugPrint("Error moving map: $e");
      }
    }
  }

  LatLng? _getSelectedEmployeeCoords() {
    if (_selectedEmployeeData == null) return null;
    
    // 1. Try latest recorded live location
    final latestLoc = _selectedEmployeeData['latestLocation'];
    if (latestLoc != null && latestLoc['latitude'] != null && latestLoc['longitude'] != null) {
      final double lat = double.parse(latestLoc['latitude'].toString());
      final double lng = double.parse(latestLoc['longitude'].toString());
      if (lat != 0.0 && lng != 0.0) {
        return LatLng(lat, lng);
      }
    }
    
    // 2. Try check-in attendance location
    final att = _selectedEmployeeData['todayAttendance'];
    if (att != null && att['latitude'] != null && att['longitude'] != null) {
      final double lat = double.parse(att['latitude'].toString());
      final double lng = double.parse(att['longitude'].toString());
      if (lat != 0.0 && lng != 0.0) {
        return LatLng(lat, lng);
      }
    }

    // 3. Try company settings coordinates
    if (_currentUser?.companyLatitude != null && _currentUser?.companyLongitude != null) {
      return LatLng(_currentUser!.companyLatitude!, _currentUser!.companyLongitude!);
    }

    return null;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
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
        _selectedDate = picked;
      });
      await _fetchTrailForSelected();
    }
  }

  Future<void> _refresh() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.fetchAllMarketingEmployees();
    
    // Maintain selection or fallback
    final allMarketing = provider.allMarketingEmployees;
    if (allMarketing.isNotEmpty) {
      final currentSelectedId = _selectedEmployeeData?['user']?['id'];
      final match = allMarketing.firstWhere(
        (e) => e['user']['id'] == currentSelectedId,
        orElse: () => allMarketing.first,
      );
      setState(() {
        _selectedEmployeeData = match;
      });
      await _fetchTrailForSelected();
    }
  }

  bool _isAuthorized() {
    if (_currentUser == null) return false;
    final role = _currentUser!.role;
    return ['system_admin', 'company_admin', 'manager', 'team_leader'].contains(role);
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '—';
    try {
      // Handles both ISO strings and standard hh:mm:ss format
      if (timeStr.contains('T') || timeStr.contains('-')) {
        final parsed = DateTime.parse(timeStr).toLocal();
        return DateFormat('hh:mm a').format(parsed);
      }
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hr = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        final dummyDateTime = DateTime(2026, 1, 1, hr, min);
        return DateFormat('hh:mm a').format(dummyDateTime);
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allMarketing = provider.allMarketingEmployees;
    final trailLogs = provider.marketingTrail;

    if (!_isAuthorized()) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 64, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                const Text('Unauthorized Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'Only Administrators, Managers, and Team Leaders have permission to monitor live marketing location trails.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Determine current date description badge
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateBadgeText = isToday 
        ? "Today — ${DateFormat('yyyy-MM-dd').format(_selectedDate)}"
        : "Date — ${DateFormat('yyyy-MM-dd').format(_selectedDate)}";

    // Setup Map markers
    final selectedCoords = _getSelectedEmployeeCoords() ?? const LatLng(_fallbackLat, _fallbackLng);

    // Build ordered list of trail points: prepend check-in location as Trail Point A
    final List<Map<String, dynamic>> orderedTrailPoints = [];

    if (_selectedEmployeeData != null) {
      final att = _selectedEmployeeData['todayAttendance'];

      // Prepend check-in attendance coordinates as Trail Point A (if available)
      if (att != null && att['latitude'] != null && att['longitude'] != null) {
        final double? lat = double.tryParse(att['latitude'].toString());
        final double? lng = double.tryParse(att['longitude'].toString());
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          orderedTrailPoints.add({
            'latitude': lat,
            'longitude': lng,
            'address': att['address'] ?? 'Check-In Location',
            'recordedAt': att['checkInTime'],
            'isCheckIn': true,
          });
        }
      }

      // Append 15-minute periodic trail logs
      for (final log in trailLogs) {
        final double? lat = double.tryParse(log['latitude']?.toString() ?? '');
        final double? lng = double.tryParse(log['longitude']?.toString() ?? '');
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          orderedTrailPoints.add({
            'latitude': lat,
            'longitude': lng,
            'address': log['address'],
            'recordedAt': log['recordedAt'],
            'isCheckIn': false,
          });
        }
      }
    }

    // Draw trail Polyline points
    final List<LatLng> polylinePoints = orderedTrailPoints.map((p) => LatLng(p['latitude'] as double, p['longitude'] as double)).toList();

    // Build labeled markers (A, B, C, ...) for each trail point
    final List<Marker> markers = [];
    if (_selectedEmployeeData != null) {
      for (int idx = 0; idx < orderedTrailPoints.length; idx++) {
        final pt = orderedTrailPoints[idx];
        final LatLng coord = LatLng(pt['latitude'] as double, pt['longitude'] as double);
        final String label = String.fromCharCode(65 + idx); // A, B, C, ...
        final bool isFirst = idx == 0;

        markers.add(
          Marker(
            point: coord,
            width: isFirst ? 48 : 32,
            height: isFirst ? 48 : 32,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFirst ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (isFirst ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isFirst ? 17 : 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : Stack(
                children: [
                  // 1. OpenStreetMap (OSM) Map Layer (Middle section)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 154, bottom: 256), // Fitted strictly between header & sheet
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: selectedCoords,
                          initialZoom: 14.5,
                          onMapReady: () {
                            setState(() {
                              _isMapReady = true;
                            });
                            final coords = _getSelectedEmployeeCoords();
                            if (coords != null) {
                              try {
                                _mapController.move(coords, 14.5);
                              } catch (e) {
                                debugPrint("Error moving map: $e");
                              }
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'd.attendance_management_app',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: polylinePoints,
                                color: const Color(0xFF2563EB),
                                strokeWidth: 3.5,
                                isDotted: false,
                              ),
                            ],
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  ),

                  // 2. Custom Sleek Header (App bar & Filters)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Bar row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Marketing Live Tracking',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      fontSize: 20,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF2563EB)),
                                  onPressed: _selectDate,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                                  onPressed: _refresh,
                                ),
                              ],
                            ),
                          ),
                          
                          // Date picker row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateBadgeText,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton(
                                  onPressed: _selectDate,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade200),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text(
                                    'Change Date',
                                    style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Horizontal list of employee cards (matches screenshot!)
                          Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: allMarketing.isEmpty
                                ? const Center(child: Text('No marketing employees found', style: TextStyle(fontSize: 12, color: Colors.grey)))
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: allMarketing.length,
                                    itemBuilder: (context, index) {
                                      final empData = allMarketing[index];
                                      final u = empData['user'];
                                      final String name = u['name'] ?? 'Staff';
                                      final bool isActive = empData['isCurrentlyActive'] == true;
                                      final bool isSelected = _selectedEmployeeData?['user']?['id'] == u['id'];

                                      return GestureDetector(
                                        onTap: () async {
                                          setState(() {
                                            _selectedEmployeeData = empData;
                                          });
                                          await _fetchTrailForSelected();
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected ? Colors.transparent : Colors.grey.shade200,
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              if (!isSelected)
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.02),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 3),
                                                ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              // Avatar with small status indicator dot
                                              Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: isSelected 
                                                        ? Colors.white.withValues(alpha: 0.2)
                                                        : const Color(0xFF2563EB).withValues(alpha: 0.08),
                                                    child: Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                                        border: Border.all(
                                                          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                  ),

                  // 3. Sliding Bottom Sheet / Details Panel (Strict height of 260 to fit perfectly)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildDetailsPanel(provider, orderedTrailPoints),
                  ),
                ],
              ),
      ),
    );
  }

  void _showTrailTimeline(List<Map<String, dynamic>> points) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) => SafeArea(
          child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Trail Timeline',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      '${points.length} point${points.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: points.isEmpty
                    ? const Center(
                        child: Text('No trail points recorded yet.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: points.length,
                        itemBuilder: (_, i) {
                          final point = points[i];
                          final label = String.fromCharCode(65 + i);
                          final bool isFirst = i == 0;
                          final address = point['address']?.toString() ?? 'Location recorded';
                          final timeStr = _formatTime(point['recordedAt']?.toString());
                          final bool isCheckIn = point['isCheckIn'] == true;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline column
                                Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFirst ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isFirst ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.25),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          label,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    if (i < points.length - 1)
                                      Container(
                                        width: 2,
                                        height: 36,
                                        color: Colors.grey.shade200,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isFirst ? 'Trail Point A (Check-In)' : 'Trail Point $label',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: isFirst ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (isCheckIn) ...[                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('Check-In', style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeStr,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(AppProvider provider, List<Map<String, dynamic>> orderedTrailPoints) {
    if (_selectedEmployeeData == null) {
      return Container(
        height: 256,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
        ),
        child: const Center(
          child: Text('No employee selected.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      );
    }

    final u = _selectedEmployeeData['user'];
    final att = _selectedEmployeeData['todayAttendance'];
    final bool isActive = _selectedEmployeeData['isCurrentlyActive'] == true;
    final String name = u['name'] ?? 'Staff';
    final String empId = u['employeeId'] ?? 'N/A';
    
    // Status checks
    final String checkInTime = att != null ? _formatTime(att['checkInTime']) : '—';
    final String checkOutTime = att != null ? _formatTime(att['checkOutTime']) : '—';
    final int pointsCount = orderedTrailPoints.length;

    return Container(
      height: 256,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sliding handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // User details header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        empId,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                // Live status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'Live' : 'Offline',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Three Status Cards Row (Check-In, Check-Out, Trail Points)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // 1. Check-In card
                Expanded(
                  child: _buildStatusCard(
                    title: 'Check-In',
                    value: checkInTime,
                    icon: Icons.login_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Check-Out card
                Expanded(
                  child: _buildStatusCard(
                    title: 'Check-Out',
                    value: checkOutTime,
                    icon: Icons.logout_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Trail Points card (tappable → opens timeline)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showTrailTimeline(orderedTrailPoints),
                    child: _buildStatusCard(
                      title: 'Trail Points',
                      value: '$pointsCount pts',
                      icon: Icons.location_on_outlined,
                      color: const Color(0xFF2563EB),
                      tappable: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Warning / Info banner at the bottom (matches screenshot perfectly!)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildInfoBanner(att, pointsCount),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool tappable = false,
  }) {
    final bool isGrey = color == const Color(0xFF64748B);

    Color bg = color.withValues(alpha: 0.05);
    Color border = color.withValues(alpha: 0.15);

    if (isGrey) {
      bg = Colors.grey.shade50;
      border = Colors.grey.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isGrey ? Colors.grey.shade600 : color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tappable)
                Icon(Icons.chevron_right_rounded, size: 13, color: color.withValues(alpha: 0.6)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: value == '—' ? Colors.grey.shade400 : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(dynamic att, int pointsCount) {
    IconData icon = Icons.info_outline_rounded;
    String text = "";
    Color bg = const Color(0xFFFEF3C7); // Yellow warning background
    Color contentColor = const Color(0xFFB45309); // Dark amber text

    if (att == null) {
      text = "Employee has not checked in today.";
      bg = Colors.grey.shade100;
      contentColor = Colors.grey.shade600;
    } else if (pointsCount == 0) {
      text = "Employee checked in but no location trail recorded yet. Location updates every 15 min.";
    } else {
      text = "Live updates active. Tracking chronological field movements.";
      bg = const Color(0xFFD1FAE5); // Green success background
      contentColor = const Color(0xFF065F46); // Dark green text
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: contentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: contentColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}