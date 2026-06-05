# Flutter wrapper keep-rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Keep Flutter background service native classes
-keep class id.flutter.flutter_background_service.** { *; }

# Keep Geolocator native classes
-keep class com.baseflow.geolocator.** { *; }

# Keep Google ML Kit Face Detection native classes
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }

# Keep In-App Update/Play Core native classes
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Flutter Secure Storage native classes
-keep class com.it_solutions.flutter_secure_storage.** { *; }
