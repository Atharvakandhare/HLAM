import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/attendance.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/app_provider.dart';
import '../utils/app_messages.dart';

class AttendanceDetailsScreen extends StatelessWidget {
  final Attendance record;

  const AttendanceDetailsScreen({super.key, required this.record});

  Future<void> _launchMaps(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Could not launch Google Maps: $e');
    }
  }

  void _showSelfieDetail(BuildContext context, String imageUrl, String title, DateTime? timestamp) {
    final isCheckIn = title.toLowerCase().contains('in');
    final address = isCheckIn ? record.address : record.checkoutAddress;

    String statusText = '';
    if (isCheckIn) {
      if (record.isLateIn) {
        statusText = 'Late Check In';
      } else if (record.isEarlyIn) {
        statusText = 'Early Check In';
      } else {
        statusText = 'Check In';
      }
    } else {
      if (record.isLateOut) {
        statusText = 'Late Check Out';
      } else if (record.isEarlyOut) {
        statusText = 'Early Check Out';
      } else {
        statusText = 'Check Out';
      }
    }

    String? fullUrl;
    if (imageUrl.isNotEmpty) {
      fullUrl = imageUrl.startsWith('http')
          ? imageUrl
          : '${ApiService.baseUrl.replaceAll('/api', '')}${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
    }

    final formattedTime = timestamp != null
        ? DateFormat('hh:mm:ss a').format(timestamp.toLocal())
        : '—';
    final formattedDate = timestamp != null
        ? DateFormat('EEEE, dd MMMM yyyy').format(timestamp.toLocal())
        : '—';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            AspectRatio(
                              aspectRatio: 3 / 4,
                              child: fullUrl != null
                                  ? Image.network(
                                      fullUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                                            SizedBox(height: 12),
                                            Text(
                                              'Failed to load selfie image',
                                              style: TextStyle(color: Colors.grey, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 48),
                                    ),
                            ),
                            // Overlaid metadata at bottom-left corner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black87],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                                        color: isCheckIn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusText.toUpperCase(),
                                        style: TextStyle(
                                          color: isCheckIn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (address != null && address.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.white70),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 16),
                    FloatingActionButton(
                      backgroundColor: Colors.white,
                      onPressed: () => Navigator.pop(context),
                      mini: true,
                      child: const Icon(Icons.close_rounded, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateObj = DateTime.parse(record.date);
    final dateStr = DateFormat('dd MMM yyyy').format(dateObj);
    final dayStr = DateFormat('EEEE').format(dateObj);
    final isLate = record.status.toLowerCase() == 'late';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance Details',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (record.user != null) _buildProfileHeaderCard(isLate),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOverviewCard(dateStr, dayStr),
                    const SizedBox(height: 16),
                    FutureBuilder<User?>(
                      future: AuthService().getUser(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final user = snapshot.data!;
                          if (user.role != 'employee') {
                            return Column(
                              children: [
                                OvertimeToggleCard(record: record, currentUser: user),
                                const SizedBox(height: 16),
                              ],
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // Mood & Energy Card
                    if (record.mood != null || record.energyLevel != null)
                      CollapsibleMoodEnergyCard(record: record),
                    if (record.mood != null || record.energyLevel != null)
                      const SizedBox(height: 16),
                    const SizedBox(height: 8),
                    _buildSectionHeader('Verification Selfies'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInteractiveSelfieCard(
                            context: context,
                            label: 'Check-in Selfie',
                            imageUrl: record.selfieUrl,
                            timestamp: record.checkInTime,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInteractiveSelfieCard(
                            context: context,
                            label: 'Check-out Selfie',
                            imageUrl: record.checkoutSelfieUrl,
                            timestamp: record.checkOutTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Check-In Location'),
                    const SizedBox(height: 10),
                    _buildLocationCard(
                      time: record.checkInTime,
                      address: record.address,
                      lat: record.latitude,
                      lng: record.longitude,
                      isCheckIn: true,
                      distanceFromOffice: record.distanceFromOffice,
                    ),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Check-Out Location'),
                    const SizedBox(height: 10),
                    _buildLocationCard(
                      time: record.checkOutTime,
                      address: record.checkoutAddress,
                      lat: record.checkoutLatitude,
                      lng: record.checkoutLongitude,
                      isCheckIn: false,
                      distanceFromOffice: record.distanceFromOffice,
                    ),
                    const SizedBox(height: 28),
                    if (record.taskComments != null && record.taskComments!.isNotEmpty) ...[
                      _buildSectionHeader('Task Comments / Notes'),
                      const SizedBox(height: 10),
                      _buildReasonCard(),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(bool isLate) {
    final statusColor = isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final user = record.user!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 22, color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  user.employeeId != null ? 'Employee ID: ${user.employeeId}' : user.email,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              record.status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String dateStr, String dayStr) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildOverviewCol(Icons.calendar_month_rounded, 'DATE', dateStr, Colors.white),
          Container(height: 36, width: 1, color: Colors.white24),
          _buildOverviewCol(Icons.today_rounded, 'DAY', dayStr, Colors.white),
          Container(height: 36, width: 1, color: Colors.white24),
          _buildOverviewCol(
            Icons.access_time_filled_rounded,
            'TOTAL HOURS',
            record.workingHours.isNotEmpty ? record.workingHours : '—',
            const Color(0xFF93C5FD),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCol(IconData icon, String label, String value, Color valueColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white60, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildInteractiveSelfieCard({
    required BuildContext context,
    required String label,
    required String? imageUrl,
    required DateTime? timestamp,
  }) {
    String? fullUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      fullUrl = imageUrl.startsWith('http')
          ? imageUrl
          : '${ApiService.baseUrl.replaceAll('/api', '')}${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  _showSelfieDetail(context, imageUrl, label, timestamp);
                }
              },
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    child: fullUrl != null
                        ? Image.network(
                            fullUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 28),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                          ),
                  ),
                  if (fullUrl != null)
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black54],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Click to view',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required DateTime? time,
    required String? address,
    required double? lat,
    required double? lng,
    required bool isCheckIn,
    double? distanceFromOffice,
  }) {
    final hasLocation = (lat != null && lng != null) || (address != null && address.isNotEmpty);
    final indicatorColor = isCheckIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: indicatorColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: indicatorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckIn ? 'Check-in Spot' : 'Check-out Spot',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (distanceFromOffice != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: distanceFromOffice < 100
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: distanceFromOffice < 100
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    distanceFromOffice < 100
                        ? 'At Office'
                        : distanceFromOffice < 1000
                            ? '${distanceFromOffice.toStringAsFixed(0)} m away'
                            : '${(distanceFromOffice / 1000).toStringAsFixed(2)} km away',
                    style: TextStyle(
                      color: distanceFromOffice < 100
                          ? const Color(0xFF10B981)
                          : const Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasLocation) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: Color(0xFFE2E8F0), height: 1),
            ),
            InkWell(
              onTap: () => _launchMaps(lat, lng),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recorded Address',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address?.isNotEmpty == true ? address! : 'Coordinates: $lat, $lng',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(Icons.open_in_new_rounded, color: Color(0xFF64748B), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Tap to open in Google Maps',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: Color(0xFFE2E8F0), height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.location_off_rounded, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 10),
                Text(
                  isCheckIn ? 'No login location recorded' : 'No logout location recorded',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.comment_rounded, color: Color(0xFFF59E0B), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason Provided',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  record.taskComments!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B), letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class CollapsibleMoodEnergyCard extends StatefulWidget {
  final Attendance record;

  const CollapsibleMoodEnergyCard({super.key, required this.record});

  @override
  State<CollapsibleMoodEnergyCard> createState() => _CollapsibleMoodEnergyCardState();
}

class _CollapsibleMoodEnergyCardState extends State<CollapsibleMoodEnergyCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = true;

  Map<String, dynamic>? _getMoodDetails(String? mood) {
    if (mood == null) return null;
    switch (mood.toLowerCase()) {
      case 'happy':
        return {
          'emoji': '😊',
          'label': 'Happy',
          'color': const Color(0xFF10B981),
        };
      case 'sad':
        return {
          'emoji': '😢',
          'label': 'Sad',
          'color': const Color(0xFF3B82F6),
        };
      case 'exhausted':
        return {
          'emoji': '😩',
          'label': 'Exhausted',
          'color': const Color(0xFFF59E0B),
        };
      case 'angry':
        return {
          'emoji': '😤',
          'label': 'Angry',
          'color': const Color(0xFFEF4444),
        };
      default:
        return {
          'emoji': '😐',
          'label': mood,
          'color': const Color(0xFF64748B),
        };
    }
  }

  Map<String, dynamic>? _getEnergyDetails(String? energy) {
    if (energy == null) return null;
    switch (energy.toLowerCase()) {
      case 'low':
        return {
          'emoji': '🔋',
          'label': 'Low',
          'color': const Color(0xFFEF4444),
        };
      case 'medium':
        return {
          'emoji': '🔋🔋',
          'label': 'Medium',
          'color': const Color(0xFFF59E0B),
        };
      case 'high':
        return {
          'emoji': '🔋🔋🔋',
          'label': 'High',
          'color': const Color(0xFF10B981),
        };
      default:
        return {
          'emoji': '⚡',
          'label': energy,
          'color': const Color(0xFF2563EB),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodObj = _getMoodDetails(widget.record.mood);
    final energyObj = _getEnergyDetails(widget.record.energyLevel);

    if (moodObj == null && energyObj == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_emotions_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Mood & Energy Status',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (moodObj != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: moodObj['color'].withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: moodObj['color'].withValues(alpha: 0.15), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(moodObj['emoji'], style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text(
                                        moodObj['label'],
                                        style: TextStyle(
                                          color: moodObj['color'],
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (moodObj != null && energyObj != null) const SizedBox(width: 8),
                              if (energyObj != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: energyObj['color'].withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: energyObj['color'].withValues(alpha: 0.15), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        energyObj['emoji'] == '🔋🔋🔋' 
                                            ? '🔋' 
                                            : energyObj['emoji'] == '🔋🔋' 
                                                ? '🔋' 
                                                : energyObj['emoji'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        energyObj['label'],
                                        style: TextStyle(
                                          color: energyObj['color'],
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(color: Color(0xFFE2E8F0), height: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            if (moodObj != null)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: moodObj['color'].withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: moodObj['color'].withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          moodObj['emoji'],
                                          style: const TextStyle(fontSize: 26),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'CURRENT MOOD',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        moodObj['label'],
                                        style: TextStyle(
                                          color: moodObj['color'],
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (moodObj != null && energyObj != null) const SizedBox(width: 16),
                            if (energyObj != null)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: energyObj['color'].withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: energyObj['color'].withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          energyObj['emoji'],
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'ENERGY LEVEL',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        energyObj['label'],
                                        style: TextStyle(
                                          color: energyObj['color'],
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class OvertimeToggleCard extends StatefulWidget {
  final Attendance record;
  final User currentUser;

  const OvertimeToggleCard({super.key, required this.record, required this.currentUser});

  @override
  State<OvertimeToggleCard> createState() => _OvertimeToggleCardState();
}

class _OvertimeToggleCardState extends State<OvertimeToggleCard> {
  late bool _overtimeAllowed;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _overtimeAllowed = widget.record.overtimeAllowed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_time_rounded, color: Color(0xFF4F46E5), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overtime Permission',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  _overtimeAllowed ? 'Allowed for this day' : 'Not allowed',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          _updating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4F46E5)),
                )
              : Switch.adaptive(
                  value: _overtimeAllowed,
                  // ignore: deprecated_member_use
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) async {
                    setState(() => _updating = true);
                    try {
                      final provider = Provider.of<AppProvider>(context, listen: false);
                      await provider.updateOvertimePermission(
                        widget.record.userId,
                        widget.record.date,
                        val,
                      );
                      if (!mounted) return;
                      setState(() {
                        _overtimeAllowed = val;
                      });
                      if (!context.mounted) return;
                      AppMessages.showSuccess(
                        context,
                        val ? 'Overtime permission granted.' : 'Overtime permission revoked.',
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      AppMessages.showError(context, e.toString().replaceFirst('Exception: ', ''));
                    } finally {
                      if (mounted) {
                        setState(() => _updating = false);
                      }
                    }
                  },
                ),
        ],
      ),
    );
  }
}

