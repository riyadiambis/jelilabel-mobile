import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/services.dart';

import 'kontrak_ocr.dart';
import 'pemindai_label.dart';
import 'pemindai_label_firebase.dart';

/// Mengambil dan mengompresi foto label menjadi JPEG; `null` jika dibatalkan.
typedef AmbilGambarLabel = Future<Uint8List?> Function();

/// Memanggil model OCR Gemini dengan byte JPEG dan mengembalikan teks JSON mentah.
typedef PanggilModelOcr = Future<String?> Function(Uint8List jpegBytes);

/// Pemindai label gizi memakai Firebase AI Logic (Gemini Developer API, paket Spark).
///
/// Mengambil gambar lewat ML Kit Document Scanner + kompresi JPEG yang sama dengan
/// [PemindaiLabelFirebase], lalu memanggil Gemini langsung via App Check tanpa API key
/// di kode aplikasi. Kuota mingguan ditegakkan secara lokal di `AsupanCubit`.
class PemindaiLabelAiLogic implements PemindaiLabel {
  PemindaiLabelAiLogic({
    AmbilGambarLabel? ambilGambar,
    PanggilModelOcr? panggilModel,
    Duration batasWaktu = const Duration(seconds: 55),
    String model = modelDefault,
  })  : _ambilGambar = ambilGambar ?? ambilDanKompresGambarLabel,
        // ignore: prefer_initializing_formals, parameter bernama tidak boleh privat
        _panggilModel = panggilModel,
        // ignore: prefer_initializing_formals, parameter bernama tidak boleh privat
        _batasWaktu = batasWaktu,
        // ignore: prefer_initializing_formals, parameter bernama tidak boleh privat
        _model = model;

  static const modelDefault = 'gemini-3.1-flash-lite';

  static const promptOcr =
      'Baca tabel Informasi Nilai Gizi pada gambar. Kembalikan JSON sesuai skema.\n'
      'Salin angka persis seperti tertulis. Jangan menebak atau menghitung.\n'
      'Jika nilai tidak terbaca atau tidak ada, isi null.\n'
      'Garam/natrium: isi natrium_mg. Jika label hanya menulis "garam" dalam gram, isi garam_g.';

  static final Schema skemaOcr = Schema.object(
    properties: {
      'terbaca': Schema.boolean(),
      'takaran_saji': Schema.object(
        nullable: true,
        properties: {
          'jumlah': Schema.number(nullable: true),
          'satuan': Schema.enumString(enumValues: ['g', 'ml'], nullable: true),
        },
        optionalProperties: ['jumlah', 'satuan'],
      ),
      'sajian_per_kemasan': Schema.number(nullable: true),
      'per_sajian': Schema.object(
        nullable: true,
        properties: {
          'energi_kkal': Schema.number(nullable: true),
          'gula_g': Schema.number(nullable: true),
          'natrium_mg': Schema.number(nullable: true),
          'garam_g': Schema.number(nullable: true),
          'lemak_total_g': Schema.number(nullable: true),
          'protein_g': Schema.number(nullable: true),
          'karbohidrat_g': Schema.number(nullable: true),
        },
        optionalProperties: [
          'energi_kkal',
          'gula_g',
          'natrium_mg',
          'garam_g',
          'lemak_total_g',
          'protein_g',
          'karbohidrat_g',
        ],
      ),
    },
    optionalProperties: ['takaran_saji', 'sajian_per_kemasan', 'per_sajian'],
  );

  final AmbilGambarLabel _ambilGambar;
  final PanggilModelOcr? _panggilModel;
  final Duration _batasWaktu;
  final String _model;
  bool _sedangPindai = false;

  Future<String?> _panggilGemini(Uint8List jpegBytes) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: skemaOcr,
        thinkingConfig: ThinkingConfig.withThinkingBudget(0),
      ),
    );
    final respons = await model.generateContent([
      Content.multi([
        const TextPart(promptOcr),
        InlineDataPart('image/jpeg', jpegBytes),
      ]),
    ]);
    return respons.text;
  }

  static bool _adalahRateLimit(Object error) {
    if (error is QuotaExceeded) return true;
    final teks = error.toString().toLowerCase();
    return teks.contains('429') ||
        teks.contains('503') ||
        teks.contains('quota') ||
        teks.contains('resource_exhausted') ||
        teks.contains('resource has been exhausted') ||
        teks.contains('too many requests') ||
        teks.contains('rate limit') ||
        teks.contains('service unavailable') ||
        teks.contains('overloaded');
  }

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
      final jpeg = await _ambilGambar();
      if (jpeg == null || jpeg.isEmpty) {
        return const HasilPindai.gagal(galat: GalatPindai.dibatalkan);
      }
      gambarDiambil = true;

      final panggil = _panggilModel ?? _panggilGemini;
      final teks = await panggil(jpeg).timeout(_batasWaktu);
      if (teks == null || teks.trim().isEmpty) {
        return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
      }

      final decoded = jsonDecode(teks);
      if (decoded is! Map) {
        return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
      }

      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      final ocr = parseResponsOcr(map);
      if (!ocr.terbaca || ocr.draf == null) {
        return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
      }
      return HasilPindai.berhasil(draf: ocr.draf!);
    } on PlatformException catch (e) {
      if (gambarDiambil) {
        return HasilPindai.gagal(
          galat: _adalahRateLimit(e) ? GalatPindai.sibuk : GalatPindai.internal,
        );
      }
      final kode = e.code.toLowerCase();
      if (kode.contains('cancel')) {
        return const HasilPindai.gagal(galat: GalatPindai.dibatalkan);
      }
      return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
    } on FormatException {
      return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
    } on TimeoutException {
      return const HasilPindai.gagal(galat: GalatPindai.deadlineExceeded);
    } on QuotaExceeded {
      return const HasilPindai.gagal(galat: GalatPindai.sibuk);
    } on FirebaseAIException catch (e) {
      return HasilPindai.gagal(
        galat: _adalahRateLimit(e) ? GalatPindai.sibuk : GalatPindai.internal,
      );
    } on SocketException {
      return const HasilPindai.gagal(galat: GalatPindai.internal);
    } catch (e) {
      return HasilPindai.gagal(
        galat: _adalahRateLimit(e) ? GalatPindai.sibuk : GalatPindai.internal,
      );
    } finally {
      _sedangPindai = false;
    }
  }
}
