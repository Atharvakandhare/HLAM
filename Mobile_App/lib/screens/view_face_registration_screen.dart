import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/app_messages.dart';
import 'face_capture_screen.dart';

class ViewFaceRegistrationScreen extends StatefulWidget {
  final User user;
  const ViewFaceRegistrationScreen({super.key, required this.user});

  @override
  State<ViewFaceRegistrationScreen> createState() => _ViewFaceRegistrationScreenState();
}

class _ViewFaceRegistrationScreenState extends State<ViewFaceRegistrationScreen> {
  bool _loading = false;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  Future<void> _updateFaceProcess() async {
    try {
      final XFile? image = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(
          builder: (context) => const FaceCaptureScreen(),
        ),
      );

      if (image == null) return;

      setState(() => _loading = true);

      final authService = AuthService();
      final response = await authService.registerFace(image);

      // Reload user profile to get the updated image path/timestamp
      final updatedUser = await authService.getUser();

      if (updatedUser != null) {
        setState(() {
          _currentUser = updatedUser;
        });
      }

      if (mounted) {
        AppMessages.showSuccess(
          context,
          response['message'] ?? 'Face descriptor updated successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    final String imageUrl = _currentUser.faceImageUrl != null
        ? "$baseUrl${_currentUser.faceImageUrl}?t=${DateTime.now().millisecondsSinceEpoch}"
        : "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Biometric Profile',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Modern styled Card enclosing the photo
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF10B981),
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Face Recognition Active',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Registered for Employee ID: ${_currentUser.employeeId ?? "N/A"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              // Reference photo frame
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  color: const Color(0xFFF1F5F9),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(
                                                Icons.face_rounded,
                                                size: 80,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.face_rounded,
                                            size: 80,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              // Info alert tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'This is your registered facial signature reference photo used during clock-in/out checks.',
                                        style: TextStyle(
                                          color: Color(0xFF1E40AF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Call to action button to re-register
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _updateFaceProcess,
                          icon: const Icon(Icons.camera_front_rounded, size: 20, color: Colors.white),
                          label: const Text(
                            'Update Face Reference',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
}
