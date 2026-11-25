import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/app_info.dart';

void main() {
  test('kAppVersion sama dengan version di pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([^\s+]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull);
    expect(kAppVersion, m!.group(1));
  });
}
