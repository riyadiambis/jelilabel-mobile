import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/cek_hasil_page.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pindai/kontrak_ocr.dart';
import 'package:jelilabel/features/pindai/layanan_iklan_admob.dart';
import 'package:jelilabel/features/pindai/pemindai_label.dart';
import 'package:jelilabel/features/pindai/pemindai_label_ai_logic.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final jpegTiruan = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

  group('PemindaiLabelAiLogic dengan model palsu', () {
    test('konfigurasi default sesuai ISSUE-11 dan AI-CONTRACT.md v1.2', () {
      expect(PemindaiLabelAiLogic.modelDefault, 'gemini-3.1-flash-lite');
      expect(PemindaiLabelAiLogic.promptOcr, contains('Informasi Nilai Gizi'));
      expect(PemindaiLabelAiLogic.promptOcr, contains('lemak_jenuh_g'));
      expect(PemindaiLabelAiLogic.promptOcr, contains('laktosa_g'));
      final skemaJson = PemindaiLabelAiLogic.skemaOcr.toJson();
      expect(skemaJson['required'], ['terbaca']);
      final perSajianProps =
          ((skemaJson['properties'] as Map)['per_sajian'] as Map)['properties'] as Map;
      expect(perSajianProps.keys, containsAll(['lemak_jenuh_g', 'laktosa_g']));
      expect(LayananIklanAdMob().pakaiSsv, isFalse);
      expect(LayananIklanAdMob(pakaiSsv: true).pakaiSsv, isTrue);
    });

    test('JSON valid mengembalikan HasilPindai.berhasil dan mengonversi garam_g', () async {
      Uint8List? bytesDiterima;
      final pemindai = PemindaiLabelAiLogic(
        ambilGambar: () async => jpegTiruan,
        panggilModel: (bytes) async {
          bytesDiterima = bytes;
          return jsonEncode({
            'terbaca': true,
            'takaran_saji': {'jumlah': 30, 'satuan': 'g'},
            'sajian_per_kemasan': 2,
            'per_sajian': {
              'energi_kkal': 140,
              'gula_g': 12,
              'natrium_mg': null,
              'garam_g': 0.5,
              'lemak_total_g': 6,
              'lemak_jenuh_g': 2.5,
              'laktosa_g': 4,
              'protein_g': 2,
              'karbohidrat_g': 19,
            },
          });
        },
      );

      final hasil = await pemindai.pindai(sisaKuotaLokal: 5);
      expect(bytesDiterima, jpegTiruan);
      expect(hasil.berhasil, isTrue);
      expect(hasil.sisaKuotaServer, isNull);
      expect(hasil.draf!.gulaG, 12);
      expect(hasil.draf!.natriumMg, 200);
      expect(hasil.draf!.lemakTotalG, 6);
      expect(hasil.draf!.lemakJenuhG, 2.5);
      expect(hasil.draf!.laktosaG, 4);
      expect(hasil.draf!.takaranJumlah, 30);
      expect(hasil.draf!.takaranSatuan, 'g');
      expect(hasil.draf!.sajianPerKemasan, 2);
    });

    test('terbaca false, gula & natrium null, atau JSON rusak -> tidakTerbaca', () async {
      for (final respons in [
        jsonEncode({'terbaca': false, 'per_sajian': {'gula_g': 10}}),
        jsonEncode({
          'terbaca': true,
          'per_sajian': {'gula_g': null, 'natrium_mg': null, 'garam_g': null},
        }),
        'bukan json',
        '',
        null,
      ]) {
        final pemindai = PemindaiLabelAiLogic(
          ambilGambar: () async => jpegTiruan,
          panggilModel: (_) async => respons,
        );
        final hasil = await pemindai.pindai(sisaKuotaLokal: 5);
        expect(hasil.berhasil, isFalse);
        expect(hasil.galat, GalatPindai.tidakTerbaca);
      }
    });

    test('HTTP 429 / QuotaExceeded -> GalatPindai.sibuk dengan pesan ramah', () async {
      for (final error in <Object>[
        QuotaExceeded('Quota exceeded for quota metric'),
        ServerException('HTTP 429 Too Many Requests'),
        FirebaseAIException('RESOURCE_EXHAUSTED: rate limit'),
      ]) {
        final pemindai = PemindaiLabelAiLogic(
          ambilGambar: () async => jpegTiruan,
          panggilModel: (_) => Future<String?>.error(error),
        );
        final hasil = await pemindai.pindai(sisaKuotaLokal: 5);
        expect(hasil.berhasil, isFalse);
        expect(hasil.galat, GalatPindai.sibuk);
        expect(pesanGalatPindai(hasil.galat!), 'Nuri sedang sibuk, coba lagi sebentar');
      }
    });

    test('galat jaringan, App Check, dan batas waktu setelah gambar diambil -> internal / deadlineExceeded', () async {
      final jaringan = PemindaiLabelAiLogic(
        ambilGambar: () async => jpegTiruan,
        panggilModel: (_) => Future<String?>.error(const SocketException('Failed host lookup')),
      );
      final resJaringan = await jaringan.pindai(sisaKuotaLokal: 5);
      expect(resJaringan.berhasil, isFalse);
      expect(resJaringan.galat, GalatPindai.internal);

      final appCheckPlatform = PemindaiLabelAiLogic(
        ambilGambar: () async => jpegTiruan,
        panggilModel: (_) => Future<String?>.error(PlatformException(code: 'app-check-failed')),
      );
      final resAppCheck = await appCheckPlatform.pindai(sisaKuotaLokal: 5);
      expect(resAppCheck.berhasil, isFalse);
      expect(resAppCheck.galat, GalatPindai.internal);

      final timeout = PemindaiLabelAiLogic(
        ambilGambar: () async => jpegTiruan,
        panggilModel: (_) => Future<String?>.error(TimeoutException('timeout')),
      );
      final resTimeout = await timeout.pindai(sisaKuotaLokal: 5);
      expect(resTimeout.berhasil, isFalse);
      expect(resTimeout.galat, GalatPindai.deadlineExceeded);
    });

    test('batal kamera dan kuota habis tidak memanggil model', () async {
      var modelDipanggil = 0;
      var kameraDipanggil = 0;

      final batal = PemindaiLabelAiLogic(
        ambilGambar: () async {
          kameraDipanggil++;
          return null;
        },
        panggilModel: (_) async {
          modelDipanggil++;
          return null;
        },
      );
      expect((await batal.pindai(sisaKuotaLokal: 5)).galat, GalatPindai.dibatalkan);
      expect(kameraDipanggil, 1);
      expect(modelDipanggil, 0);

      final batalPlatform = PemindaiLabelAiLogic(
        ambilGambar: () => Future<Uint8List?>.error(PlatformException(code: 'CANCELED')),
        panggilModel: (_) async {
          modelDipanggil++;
          return null;
        },
      );
      expect((await batalPlatform.pindai(sisaKuotaLokal: 5)).galat, GalatPindai.dibatalkan);
      expect(modelDipanggil, 0);

      final habis = PemindaiLabelAiLogic(
        ambilGambar: () async {
          kameraDipanggil++;
          return jpegTiruan;
        },
        panggilModel: (_) async {
          modelDipanggil++;
          return null;
        },
      );
      expect((await habis.pindai(sisaKuotaLokal: 0)).galat, GalatPindai.resourceExhausted);
      expect(kameraDipanggil, 1);
      expect(modelDipanggil, 0);
    });
  });

  group('Penegakan kuota lokal & UI pada mode Spark', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
    });

    tearDown(() async {
      await resetDependensi();
    });

    test('kuota hanya berkurang saat label terbaca; 429, tidak terbaca, dan galat jaringan tidak mengurangi', () async {
      final basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      addTearDown(basis.tutup);
      final repo = AsupanRepository(basis.db);
      final sekarang = DateTime(2026, 11, 21, 10, 0);

      var mode = 'sukses';
      final pemindai = PemindaiLabelAiLogic(
        ambilGambar: () async => jpegTiruan,
        panggilModel: (_) async {
          switch (mode) {
            case 'sukses':
              return jsonEncode({
                'terbaca': true,
                'per_sajian': {'gula_g': 9, 'natrium_mg': 80},
              });
            case 'tidak_terbaca':
              return jsonEncode({'terbaca': false});
            case '429':
              throw QuotaExceeded('429 Too Many Requests');
            default:
              throw const SocketException('offline');
          }
        },
      );

      final cubit = AsupanCubit(repo, jam: () => sekarang, pemindaiLabel: pemindai);
      await cubit.muat();
      expect(cubit.state.sisaKuota, 5);

      expect((await cubit.pindaiLabel()).berhasil, isTrue);
      expect(cubit.state.sisaKuota, 4);
      expect(await repo.bacaKuotaTerpakai(sekarang), 1);

      for (final gagalMode in const ['tidak_terbaca', '429', 'jaringan']) {
        mode = gagalMode;
        final res = await cubit.pindaiLabel();
        expect(res.berhasil, isFalse);
        expect(cubit.state.sisaKuota, 4);
        expect(await repo.bacaKuotaTerpakai(sekarang), 1);
      }
      await cubit.close();
    });

    testWidgets('galat 429 menampilkan layar galat "Nuri sedang sibuk, coba lagi sebentar" tanpa mengurangi kuota',
        (t) async {
      final pemindai429 = PemindaiLabelAiLogic(
        ambilGambar: () async => jpegTiruan,
        panggilModel: (_) => Future<String?>.error(QuotaExceeded('429')),
      );
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiLabel: pemindai429);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();
      expect(find.text('Sisa 5 dari 5 minggu ini'), findsOneWidget);

      await t.tap(find.text('Pindai Label Gizi'));
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      expect(find.text('Nuri sedang sibuk, coba lagi sebentar'), findsOneWidget);
      expect(find.text('Foto ulang'), findsOneWidget);
      expect(find.text('Isi manual'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();
      expect(find.text('Sisa 5 dari 5 minggu ini'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('galat jaringan dan App Check menampilkan layar galat dengan Isi manual tanpa mengurangi kuota',
        (t) async {
      for (final error in <Object>[
        const SocketException('Failed host lookup'),
        FirebaseAIException('App Check token rejected'),
      ]) {
        final pemindaiGagal = PemindaiLabelAiLogic(
          ambilGambar: () async => jpegTiruan,
          panggilModel: (_) => Future<String?>.error(error),
        );
        await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiLabel: pemindaiGagal);

        await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
        await t.pumpAndSettle();

        await t.tap(find.text('Pindai Label Gizi'));
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();

        expect(find.text('Tidak ada internet'), findsOneWidget);
        expect(find.text('Coba lagi'), findsOneWidget);
        expect(find.text('Isi manual'), findsOneWidget);
        expect(await getIt<AsupanRepository>().bacaKuotaTerpakai(DateTime.now()), 0);

        await t.ensureVisible(find.text('Isi manual'));
        await t.tap(find.text('Isi manual'));
        await t.pumpAndSettle();
        expect(find.byType(CekHasilPage), findsOneWidget);
        expect(find.text('Isi manual'), findsOneWidget);

        await t.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('batal scanner kembali ke Beranda tanpa pesan dan tanpa mengurangi kuota', (t) async {
      final pemindaiBatal = PemindaiLabelAiLogic(
        ambilGambar: () async => null,
        panggilModel: (_) async => throw StateError('tidak boleh dipanggil'),
      );
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiLabel: pemindaiBatal);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.tap(find.text('Pindai Label Gizi'));
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      expect(find.text('Pindai Label Gizi'), findsOneWidget);
      expect(find.text('Sisa 5 dari 5 minggu ini'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Tidak ada internet'), findsNothing);
      expect(find.text('Label tidak terbaca'), findsNothing);

      await t.pumpWidget(const SizedBox.shrink());
    });

    test('tanpa konfigurasi native, siapkanDependensi memakai PemindaiLabelSimulasi', () async {
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
      expect(getIt<PemindaiLabel>(), isA<PemindaiLabelSimulasi>());
    });
  });
}
