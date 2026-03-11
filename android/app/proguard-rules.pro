# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# TFLite Flutter plugin (JNI bridge)
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep all native (JNI) method bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable creators (needed by various Android framework classes)
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep enums (R8 can strip them otherwise)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
