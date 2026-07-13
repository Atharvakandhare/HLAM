import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_messages.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        if (mounted) {
          AppMessages.showError(
            context,
            'Camera permission is strictly required to capture your face.',
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
        ResolutionPreset.medium,
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

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      debugPrint("Capture Error: $e");
      if (mounted) {
        AppMessages.showError(context, "Failed to capture image: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Preview
          _isCameraInitialized || _capturedImage != null
              ? _buildFullscreenPreview()
              : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),

          // 2. Custom Face Guide Overlay
          if (_capturedImage == null && _isCameraInitialized)
            _buildFaceOverlay(),

          // 3. Instruction Banner at Top
          if (_capturedImage == null && _isCameraInitialized)
            _buildInstructionHeader(),

          // 4. SafeArea Controls (Buttons at the bottom)
          SafeArea(
            child: Stack(
              children: [
                // Top Close Button
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Bottom Buttons
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _capturedImage == null
                        ? _buildShutterButton()
                        : _buildConfirmationActions(),
                  ),
                ),
              ],
            ),
          ),

          // 5. Processing Loader Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
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

  Widget _buildFaceOverlay() {
    return IgnorePointer(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withOpacity(0.7),
          BlendMode.srcOut,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 60),
                height: 380,
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(190),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionHeader() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Positioned(
      top: statusBarHeight + 80,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Column(
          children: [
            const Text(
              'Face Registration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Align your face inside the guide and look directly at the front camera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _captureImage,
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_front_rounded,
            color: Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retake Button
        GestureDetector(
          onTap: () => setState(() {
            _capturedImage = null;
          }),
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        // Confirm Button
        GestureDetector(
          onTap: () => Navigator.pop(context, _capturedImage),
          child: Container(
            height: 60,
            width: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
