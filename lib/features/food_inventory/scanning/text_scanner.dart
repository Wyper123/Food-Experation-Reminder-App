import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads printed text from a photo. ML Kit runs on the device, offline.
abstract class TextScanner {
  Future<String> readText(String imagePath);
  Future<void> close();

  /// ML Kit only exists for Android and iOS.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

class MlKitTextScanner implements TextScanner {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> readText(String imagePath) async =>
      (await _recognizer.processImage(InputImage.fromFilePath(imagePath))).text;

  @override
  Future<void> close() => _recognizer.close();
}
