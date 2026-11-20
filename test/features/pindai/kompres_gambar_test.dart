import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jelilabel/features/pindai/pemindai_label_firebase.dart';

void main() {
  group('kompresGambarLabel', () {
    test('mengecilkan gambar 2400x1800 menjadi JPEG <= 1600 px dan <= 1 MB', () {
      final sumber = img.Image(width: 2400, height: 1800);
      img.fill(sumber, color: img.ColorRgb8(240, 220, 180));
      final pngBytes = img.encodePng(sumber);

      final hasil = kompresGambarLabel(pngBytes);
      expect(hasil.length, lessThanOrEqualTo(1048576));
      expect(hasil.sublist(0, 3), [0xFF, 0xD8, 0xFF]);

      final terdekode = img.decodeJpg(hasil);
      expect(terdekode, isNotNull);
      expect(terdekode!.width, 1600);
      expect(terdekode.height, 1200);
    });

    test('gambar kecil 600x400 tidak di-upscale dan tetap menjadi JPEG valid', () {
      final kecil = img.Image(width: 600, height: 400);
      img.fill(kecil, color: img.ColorRgb8(180, 210, 190));
      final jpgBytes = img.encodeJpg(kecil, quality: 95);

      final hasil = kompresGambarLabel(jpgBytes);
      final terdekode = img.decodeJpg(hasil);
      expect(terdekode, isNotNull);
      expect(terdekode!.width, 600);
      expect(terdekode.height, 400);
    });

    test('byte tidak valid melempar FormatException', () {
      expect(() => kompresGambarLabel(Uint8List.fromList([1, 2, 3, 4])), throwsFormatException);
    });
  });
}
