# Keep MediaPipe classes for flutter_gemma
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Keep TensorFlow Lite classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep Google flatbuffers
-keep class com.google.flatbuffers.** { *; }
-dontwarn com.google.flatbuffers.**
