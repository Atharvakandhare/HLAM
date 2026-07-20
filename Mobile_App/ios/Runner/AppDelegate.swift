import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let faceChannel = FlutterMethodChannel(name: "com.hlam.app/face_detection",
                                              binaryMessenger: controller.binaryMessenger)
    
    faceChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "detectFace" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "FilePath is missing", details: nil))
          return
        }
        self.detectFace(filePath: filePath, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func detectFace(filePath: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: filePath)
    
    let request = VNDetectFaceRectanglesRequest { (req, error) in
      if let err = error {
        result(FlutterError(code: "VISION_ERROR", message: err.localizedDescription, details: nil))
        return
      }
      
      guard let results = req.results as? [VNFaceObservation] else {
        result(false)
        return
      }
      
      result(!results.isEmpty)
    }
    
    let handler = VNImageRequestHandler(url: fileURL, options: [:])
    do {
      try handler.perform([request])
    } catch {
      result(FlutterError(code: "HANDLER_ERROR", message: error.localizedDescription, details: nil))
    }
  }
}
