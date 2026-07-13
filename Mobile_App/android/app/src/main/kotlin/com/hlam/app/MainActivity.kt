package com.hlam.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import java.io.File
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hlam.app/face_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "detectFace") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    detectFace(filePath, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "FilePath is missing", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun detectFace(filePath: String, result: MethodChannel.Result) {
        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File does not exist", null)
            return
        }

        try {
            val image = InputImage.fromFilePath(context, Uri.fromFile(file))
            val options = FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                .build()
            val detector = FaceDetection.getClient(options)

            detector.process(image)
                .addOnSuccessListener { faces ->
                    result.success(faces.isNotEmpty())
                }
                .addOnFailureListener { e ->
                    result.error("ML_KIT_ERROR", e.localizedDescription, null)
                }
        } catch (e: Exception) {
            result.error("PROCESS_ERROR", e.localizedDescription, null)
        }
    }
}
