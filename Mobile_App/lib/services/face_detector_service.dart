import 'package:flutter/services.dart';

class NativeFaceDetector {
  static const MethodChannel _channel = MethodChannel('com.hlam.app/face_detection');

  /// Detects if at least one face is present in the image at the given path.
  static Future<bool> isFacePresent(String filePath) async {
    try {
      final bool result = await _channel.invokeMethod('detectFace', {'filePath': filePath});
      return result;
    } catch (e) {
      return false;
    }
  }
}
