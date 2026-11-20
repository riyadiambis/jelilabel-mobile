import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

({int lebar, int tinggi}) _dimensiPng(String path) {
  final berkas = File(path);
  expect(berkas.existsSync(), isTrue, reason: 'Berkas $path harus ada');
  final bytes = berkas.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24));
  expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(bytes);
  return (lebar: data.getUint32(16), tinggi: data.getUint32(20));
}

void main() {
  test('master assets/ikon/*.png berukuran minimal 1024x1024 px', () {
    for (final path in [
      'assets/ikon/ikon.png',
      'assets/ikon/ikon-depan.png',
      'assets/ikon/splash.png',
    ]) {
      final d = _dimensiPng(path);
      expect(d.lebar, greaterThanOrEqualTo(1024), reason: path);
      expect(d.tinggi, greaterThanOrEqualTo(1024), reason: path);
    }
  });

  test('ikon launcher mipmap memiliki ukuran tepat 48, 72, 96, 144, 192 px', () {
    const target = {
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    };
    for (final entry in target.entries) {
      final d = _dimensiPng(entry.key);
      expect(d.lebar, entry.value, reason: entry.key);
      expect(d.tinggi, entry.value, reason: entry.key);
    }
  });

  test('foreground adaptive icon dan splash di res/ memiliki dimensi sesuai kerapatan', () {
    const fgTarget = {
      'android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png': 108,
      'android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png': 162,
      'android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png': 216,
      'android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png': 324,
      'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png': 432,
    };
    for (final entry in fgTarget.entries) {
      final d = _dimensiPng(entry.key);
      expect(d.lebar, entry.value, reason: entry.key);
      expect(d.tinggi, entry.value, reason: entry.key);
    }

    const splashTarget = {
      'drawable-mdpi': 288,
      'drawable-hdpi': 432,
      'drawable-xhdpi': 576,
      'drawable-xxhdpi': 864,
      'drawable-xxxhdpi': 1152,
    };
    for (final entry in splashTarget.entries) {
      for (final p in [
        'android/app/src/main/res/${entry.key}/splash.png',
        'android/app/src/main/res/${entry.key}/android12splash.png',
        'android/app/src/main/res/${entry.key.replaceFirst('drawable-', 'drawable-night-')}/android12splash.png',
      ]) {
        final d = _dimensiPng(p);
        expect(d.lebar, entry.value, reason: p);
        expect(d.tinggi, entry.value, reason: p);
      }
    }
  });

  test('maskot-06-waspada.png ada dan terdaftar di pubspec.yaml', () {
    final d = _dimensiPng('assets/maskot/maskot-06-waspada.png');
    expect(d.lebar, greaterThan(0));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/maskot/'));
  });

  test('AndroidManifest memakai label JeliLabel dan tanpa izin CAMERA', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="JeliLabel"'));
    expect(manifest, isNot(contains('android.permission.CAMERA')));
  });
}
