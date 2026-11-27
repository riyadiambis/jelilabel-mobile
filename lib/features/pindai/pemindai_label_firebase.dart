import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;

import 'kontrak_ocr.dart';
import 'pemindai_label.dart';

/// Memutar orientasi EXIF, mengecilkan sisi terpanjang ke maks 1600 px,
/// dan mengompresi gambar ke JPEG <= 1 MB untuk dikirim ke Cloud Functions.
Uint8List kompresGambarLabel(
  Uint8List bytes, {
  int maksSisi = 1600,
  int maksByte = 1048576,
}) {
  final awal = img.decodeImage(bytes);
  if (awal == null) {
    throw const FormatException('Gambar label tidak dapat didekode.');
  }
  var gambar = img.bakeOrientation(awal);
  if (gambar.width > maksSisi || gambar.height > maksSisi) {
    gambar = gambar.width >= gambar.height
        ? img.copyResize(gambar, width: maksSisi, interpolation: img.Interpolation.linear)
        : img.copyResize(gambar, height: maksSisi, interpolation: img.Interpolation.linear);
  }
  for (final kualitas in const [85, 72, 58, 45]) {
    final hasil = img.encodeJpg(gambar, quality: kualitas);
    if (hasil.length <= maksByte) return hasil;
  }
  return img.encodeJpg(gambar, quality: 35);
}

Map<String, dynamic> _normMap(Map<Object?, Object?> raw) => {
      for (final entry in raw.entries)
        if (entry.key != null) entry.key.toString(): _normNilai(entry.value),
    };

Object? _normNilai(Object? v) {
  if (v is Map<Object?, Object?>) return _normMap(v);
  if (v is List<Object?>) return v.map(_normNilai).toList();
  return v;
}

/// Memindai satu halaman label gizi memakai ML Kit Document Scanner (tanpa izin CAMERA)
/// lalu mengompresinya ke JPEG <= 1 MB pada isolate terpisah.
/// Mengembalikan `null` jika pengguna membatalkan pemindaian.
Future<Uint8List?> ambilDanKompresGambarLabel() async {
  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormats: const {DocumentFormat.jpeg},
      mode: ScannerMode.filter,
      pageLimit: 1,
      isGalleryImport: true, // foto label yang sudah ada di galeri juga bisa dipindai
    ),
  );
  try {
    final result = await scanner.scanDocument();
    final images = result.images;
    if (images == null || images.isEmpty) return null;

    final uriOrPath = images.first;
    final pathBerkas = uriOrPath.startsWith('file://') ? Uri.parse(uriOrPath).toFilePath() : uriOrPath;
    final mentah = await File(pathBerkas).readAsBytes();
    return await Isolate.run(() => kompresGambarLabel(mentah));
  } finally {
    await scanner.close();
  }
}

/// Implementasi produksi pemindai label memakai ML Kit Document Scanner
/// (tanpa izin CAMERA di aplikasi) dan Cloud Functions `pindaiLabelGizi` (`K-9 Opsi A`).
class PemindaiLabelFirebase implements PemindaiLabel {
  PemindaiLabelFirebase();

  bool _sedangPindai = false;

  @override
  Future<HasilPindai> pindai({required int sisaKuotaLokal}) async {
    if (sisaKuotaLokal <= 0) {
      return const HasilPindai.gagal(galat: GalatPindai.resourceExhausted);
    }
    if (_sedangPindai) {
      return const HasilPindai.gagal(galat: GalatPindai.dibatalkan);
    }
    _sedangPindai = true;
    var gambarDiambil = false;

    try {
      final jpeg = await ambilDanKompresGambarLabel();
      if (jpeg == null || jpeg.isEmpty) {
        return const HasilPindai.gagal(galat: GalatPindai.dibatalkan);
      }
      gambarDiambil = true;

      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user == null) {
        return const HasilPindai.gagal(galat: GalatPindai.unauthenticated);
      }

      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2').httpsCallable(
        'pindaiLabelGizi',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 55)),
      );
      final respons = await callable.call<dynamic>({
        'gambarBase64': base64Encode(jpeg),
        'versiKontrak': 2,
      });

      final data = respons.data;
      if (data is! Map<Object?, Object?>) {
        return const HasilPindai.gagal(galat: GalatPindai.internal);
      }
      final ocr = parseResponsOcr(_normMap(data));
      if (!ocr.terbaca || ocr.draf == null) {
        return HasilPindai.gagal(
          galat: GalatPindai.tidakTerbaca,
          sisaKuotaServer: ocr.kuota?.sisa,
        );
      }
      return HasilPindai.berhasil(
        draf: ocr.draf!,
        sisaKuotaServer: ocr.kuota?.sisa,
      );
    } on FirebaseFunctionsException catch (e) {
      return HasilPindai.gagal(galat: galatPindaiDariKode(e.code));
    } on PlatformException catch (e) {
      if (gambarDiambil) {
        return const HasilPindai.gagal(galat: GalatPindai.internal);
      }
      final kode = e.code.toLowerCase();
      if (kode.contains('cancel')) {
        return const HasilPindai.gagal(galat: GalatPindai.dibatalkan);
      }
      return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
    } on FormatException {
      return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
    } catch (_) {
      return const HasilPindai.gagal(galat: GalatPindai.internal);
    } finally {
      _sedangPindai = false;
    }
  }
}
