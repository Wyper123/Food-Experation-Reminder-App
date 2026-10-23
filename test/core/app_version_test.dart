import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';

void main() {
  test('the version shown in the app matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([\d.]+)\+', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(AppConstants.appVersion, version);
  });
}
