import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_provider.dart';
import '../utils/app_messages.dart';

class AttendanceCaptureScreen extends StatefulWidget {
  final bool isCheckout;
  final int? checkoutAttendanceId;
  final String? checkoutReason;
  final String? mood;
  final String? energyLevel;

  const AttendanceCaptureScreen({
    super.key,
    required this.isCheckout,
    this.checkoutAttendanceId,
    this.checkoutReason,
    this.mood,
    this.energyLevel,
  });

  @override
  State<AttendanceCaptureScreen> createState() =>
      _AttendanceCaptureScreenState();
}

class _AttendanceCaptureScreenState extends State<AttendanceCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  XFile? _capturedImage;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animations FIRST to avoid potential race conditions
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request Camera, Location, and Notification permissions explicitly
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.location,
        Permission.notification,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.location] != PermissionStatus.granted ||
          statuses[Permission.notification] != PermissionStatus.granted) {
        if (mounted) {
          AppMessages.showError(
            context,
            'Camera, Location, and Notification permissions are strictly required to verify your attendance and keep location tracking running. Please grant them in App Settings.',
          );
          Navigator.pop(context);
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset
            .medium, // Natively captures around 720p/640x480 - reduces raw file size from 6MB to 200KB!
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  /// Applies a timestamp + location watermark banner and saves as JPEG.
  /// Returns a new File with a guaranteed .jpg extension so the server's
  /// `sharp` library can decode it correctly (previously PNG bytes were
  /// written into a .jpg path which caused upload failures for some users).
  Future<File> _applyWatermark({
    required File file,
    required bool isCheckout,
    required DateTime dateTime,
    required String? address,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image originalImage = frame.image;

      final int srcWidth = originalImage.width;
      final int srcHeight = originalImage.height;

      // ── Scale down to max 900 px wide before watermarking ──────────────────
      // Camera photos can be 12–48 MP. Uploading a full-res PNG through ngrok
      // saturates Jimp (pure-JS) and causes 503 timeouts. Scaling here keeps
      // the output to ~300–800 KB while still looking fine on any screen.
      const int maxUploadWidth = 900;
      final double scaleFactor =
          srcWidth > maxUploadWidth ? maxUploadWidth / srcWidth : 1.0;
      final int outWidth = (srcWidth * scaleFactor).round();
      final int outHeight = (srcHeight * scaleFactor).round();

      // Re-use the *original* dimensions for all proportional calculations so
      // the watermark layout math stays the same — canvas.scale() applies them.
      final double w = srcWidth.toDouble();
      final double h = srcHeight.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Apply scale so the canvas renders at reduced pixel dimensions
      if (scaleFactor < 1.0) {
        canvas.scale(scaleFactor, scaleFactor);
      }

      // Draw the original image
      canvas.drawImage(originalImage, Offset.zero, Paint());

      // Banner configuration at bottom (18% of image height)
      final double bannerHeight = h * 0.18;
      final double bannerY = h - bannerHeight;

      // Draw semi-transparent dark banner background
      final bannerPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, bannerY, w, bannerHeight),
        bannerPaint,
      );

      // Draw side indicator accent line
      final accentPaint = Paint()
        ..color = isCheckout ? const Color(0xFFEF4444) : const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, bannerY, w * 0.02, bannerHeight),
        accentPaint,
      );

      // Setup styles based on resolution
      final double textPaddingLeft = w * 0.05;
      final double titleFontSize = h * 0.034;
      final double infoFontSize = h * 0.024;

      final timeStr = DateFormat('hh:mm:ss a').format(dateTime);
      final dateStr = DateFormat('dd MMM yyyy').format(dateTime);
      final titleText = isCheckout ? "CHECK-OUT VERIFIED" : "CHECK-IN VERIFIED";

      // Draw Title Text
      final titlePainter = TextPainter(
        text: TextSpan(
          text: titleText,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      titlePainter.layout(maxWidth: w * 0.9);
      titlePainter.paint(
        canvas,
        Offset(textPaddingLeft, bannerY + (bannerHeight * 0.14)),
      );

      // Draw Info text
      final locationStr = (address != null && address.isNotEmpty)
          ? address
          : "Coordinates captured";
      final infoText = "Date: $dateStr  |  Time: $timeStr\n$locationStr";

      final infoPainter = TextPainter(
        text: TextSpan(
          text: infoText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: infoFontSize,
            height: 1.3,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      infoPainter.layout(maxWidth: w * 0.9);
      infoPainter.paint(
        canvas,
        Offset(
          textPaddingLeft,
          bannerY + (bannerHeight * 0.14) + titlePainter.height + 4,
        ),
      );

      // Rasterise at the *scaled-down* resolution
      final picture = recorder.endRecording();
      final watermarkedUiImage = await picture.toImage(outWidth, outHeight);

      // Encode as PNG (Flutter has no native JPEG encoder for ui.Image).
      // At 900 px wide the PNG is only 300–800 KB — Jimp on the server
      // compresses it to quality-60 JPEG in well under a second.
      final pngData = await watermarkedUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngData != null) {
        final String pngPath = p.join(
          p.dirname(file.path),
          'watermarked_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        final pngFile = File(pngPath);
        await pngFile.writeAsBytes(pngData.buffer.asUint8List());
        debugPrint(
          "[Attendance] Watermarked selfie saved (${outWidth}x$outHeight): $pngPath",
        );
        return pngFile;
      }
    } catch (e) {
      debugPrint("Error drawing watermark: $e");
    }
    // Return original file unmodified if watermark fails — still allow check-in
    return file;
  }

  Future<void> _captureAndSubmit() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture provider reference BEFORE any await to avoid BuildContext async gap lint
      final provider = Provider.of<AppProvider>(context, listen: false);

      // 1. Capture Image
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });

      // 2. Get Location (with 20s timeout to avoid hanging on poor GPS)
      await provider.getCurrentPosition();

      if (provider.currentPosition == null) {
        throw Exception(
          "Location not available. Please enable GPS and grant Location permission to this app, then retry.",
        );
      }

      setState(() {});

      // 3. Apply Watermark — saves as .png with matching content so server can decode it
      final File watermarkedFile = await _applyWatermark(
        file: File(image.path),
        isCheckout: widget.isCheckout,
        dateTime: DateTime.now(),
        address:
            provider.currentAddress ??
            "${provider.currentPosition!.latitude.toStringAsFixed(5)}, "
                "${provider.currentPosition!.longitude.toStringAsFixed(5)}",
      );
      final XFile finalImage = XFile(watermarkedFile.path);
      debugPrint(
        "[Attendance] Uploading watermarked file: ${watermarkedFile.path}",
      );

      // 4. Submit to Backend
      if (widget.isCheckout) {
        final attendanceId =
            provider.todayAttendance?.id ?? widget.checkoutAttendanceId;
        if (attendanceId == null) {
          throw Exception("No active check-in found. Please contact admin.");
        }

        await provider.checkOut(
          attendanceId: attendanceId,
          checkoutSelfieFile: finalImage,
          lat: provider.currentPosition!.latitude,
          long: provider.currentPosition!.longitude,
          address: provider.currentAddress,
          taskComments: widget.checkoutReason,
        );
      } else {
        await provider.checkIn(
          selfieFile: finalImage,
          lat: provider.currentPosition!.latitude,
          long: provider.currentPosition!.longitude,
          address: provider.currentAddress,
          mood: widget.mood,
          energyLevel: widget.energyLevel,
        );
      }

      if (mounted) {
        AppMessages.showSuccess(
          context,
          widget.isCheckout
              ? 'Check-out recorded successfully!'
              : 'Check-in recorded successfully!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("[Attendance] Submit error: $e");
      if (mounted) {
        // Strip 'Exception:' prefix for cleaner message
        final msg = e.toString().replaceFirst('Exception: ', '');
        AppMessages.showError(context, msg);
      }
      setState(() {
        _capturedImage = null; // Allow retry
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. True Fullscreen Immersive Preview
          _isCameraInitialized || _capturedImage != null
              ? _buildFullscreenPreview()
              : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),

          // 2. Large Minimalist Pulse Guide
          if (_capturedImage == null && _isCameraInitialized)
            _buildMinimalistGuide(),

          // 3. SafeArea Overlay for All Interactive Controls
          SafeArea(
            child: Stack(
              children: [
                // Top Close Action Button (notch safe)
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Bottom Shutter / Retake Actions (home indicator safe)
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _capturedImage == null
                        ? _buildMinimalShutter()
                        : _buildRetakeAction(),
                  ),
                ),
              ],
            ),
          ),

          // 4. Verification Overlay
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'VERIFYING...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_capturedImage != null) {
          return Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.cover,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          );
        }

        // Calculate scaling factor to fill screen without distortion
        final size = constraints.biggest;
        var scale = size.aspectRatio * _controller!.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;

        return Transform.scale(
          scale: scale,
          child: Center(child: CameraPreview(_controller!)),
        );
      },
    );
  }

  Widget _buildMinimalistGuide() {
    if (_pulseAnimation == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80), // Slightly offset upwards
        child: AnimatedBuilder(
          animation: _pulseAnimation!,
          builder: (context, child) {
            return Container(
              height: 420,
              width: 320,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(200),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: 0.2 * _pulseAnimation!.value),
                    blurRadius: 30 * _pulseAnimation!.value,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMinimalShutter() {
    return GestureDetector(
      onTap: _isProcessing ? null : _captureAndSubmit,
      child: Container(
        height: 84,
        width: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.black,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildRetakeAction() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: () => setState(() {
            _capturedImage = null;
          }),
          child: const Icon(Icons.refresh_rounded, color: Colors.black),
        ),
        const SizedBox(height: 12),
        const Text(
          'RETAKE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
