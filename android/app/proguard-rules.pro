# R8 rules for release builds.

# google_mlkit_text_recognition references every ML Kit script model, but the
# app only bundles the Latin one (expiry labels are Latin text). The others
# are optional dependencies, so their absence is expected.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
