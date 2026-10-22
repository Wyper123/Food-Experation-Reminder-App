# R8 rules for release builds. Debug builds skip R8, so problems here only
# show up in release APKs: test those on a real phone.

# Several plugins are called from Dart by class/method *name* (JNI), which R8
# cannot see. Renaming broke shared_preferences at startup (the app stayed on
# the launch screen), so keep shrinking but never rename anything.
-dontobfuscate

# JNI-based plugins: their methods look unused to R8 but are called from Dart.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# ML Kit creates its component registrars by reflection (no-arg constructors);
# without this, text recognition fails to start in release builds.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }

# google_mlkit_text_recognition references every ML Kit script model, but the
# app only bundles the Latin one (expiry labels are Latin text). The others
# are optional dependencies, so their absence is expected.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
