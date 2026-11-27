import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/ambang.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/bandingkan/domain/bandingkan_produk.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void _layarSempit(WidgetTester t) {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
  });

  tearDown(() async {
    await resetDependensi();
  });

  group('Domain bandingkanProduk (ISSUE-21 A)', () {
    test('menghitung selisih pada zat fokus default gula dan persen jatah harian', () {
      const a = ProdukRingkas(
        id: 1,
        nama: 'Teh Manis Botol',
        takaranJumlah: 350,
        takaranSatuan: 'ml',
        gulaG: 18,
        natriumMg: 600,
        lemakTotalG: 0,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );
      const b = ProdukRingkas(
        id: 2,
        nama: 'Teh Kurang Manis',
        takaranJumlah: 350,
        takaranSatuan: 'ml',
        gulaG: 8,
        natriumMg: 590,
        lemakTotalG: 0,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );

      final hasil = bandingkanProduk(a, b);
      expect(hasil.pilihanLebihRingan, PihakRingan.b);
      expect(hasil.takaranBerbeda, isFalse);
      expect(hasil.judulTakaran, 'Per 350 ml');
      expect(hasil.kalimatRingkas, 'B lebih ringan 10 g gula. Itu 20% dari jatah gula harianmu.');
      expect(hasil.kalimatRingkas.toLowerCase(), isNot(contains('sehat')));
    });

    test('mengikuti zat fokus natrium dan batas aktif profil', () {
      const a = ProdukRingkas(
        id: 1,
        nama: 'Mi A',
        takaranJumlah: 85,
        takaranSatuan: 'g',
        gulaG: 4,
        natriumMg: 1200,
        lemakTotalG: 14,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );
      const b = ProdukRingkas(
        id: 2,
        nama: 'Mi B',
        takaranJumlah: 85,
        takaranSatuan: 'g',
        gulaG: 6,
        natriumMg: 700,
        lemakTotalG: 12,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );

      final hasil = bandingkanProduk(
        a,
        b,
        batas: const BatasHarian(natriumMg: 1500, sumber: SumberBatas.dariDokter),
        fokus: FokusZat.natrium,
      );
      expect(hasil.pilihanLebihRingan, PihakRingan.b);
      expect(hasil.kalimatRingkas, 'B lebih ringan 500 mg natrium. Itu 33% dari jatah natrium harianmu.');
    });

    test('nilai sama menampilkan "Gula keduanya sama."', () {
      const a = ProdukRingkas(
        id: 1,
        nama: 'Teh A',
        takaranJumlah: 350,
        takaranSatuan: 'ml',
        gulaG: 12,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );
      const b = ProdukRingkas(
        id: 2,
        nama: 'Teh B',
        takaranJumlah: 350,
        takaranSatuan: 'ml',
        gulaG: 12,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );

      final hasil = bandingkanProduk(a, b);
      expect(hasil.pilihanLebihRingan, isNull);
      expect(hasil.kalimatRingkas, 'Gula keduanya sama.');
    });

    test('takaran berbeda jumlah atau satuan menandai takaranBerbeda dan memakai Per sajian', () {
      const a = ProdukRingkas(
        id: 1,
        nama: 'Susu Kotak',
        takaranJumlah: 200,
        takaranSatuan: 'ml',
        gulaG: 10,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );
      const b = ProdukRingkas(
        id: 2,
        nama: 'Biskuit',
        takaranJumlah: 30,
        takaranSatuan: 'g',
        gulaG: 6,
        jumlahKali: 1,
        terakhirDicatat: 1000,
      );

      final hasil = bandingkanProduk(a, b);
      expect(hasil.takaranBerbeda, isTrue);
      expect(hasil.judulTakaran, 'Per sajian');
      expect(hasil.kalimatRingkas, 'B lebih ringan 4 g gula. Itu 8% dari jatah gula harianmu.');
      expect(hasil.nutriLevelA, isNotNull);
      expect(hasil.nutriLevelB, isNull);
    });
  });

  group('UI BandingkanPage dari Beranda dan Produk saya (320 px)', () {
    testWidgets('masuk dari Beranda, pilih 2 produk via cari nama, beda takaran, Catat B, tanpa produk ketiga',
        (t) async {
      _layarSempit(t);
      final repo = getIt<AsupanRepository>();
      await repo.simpanKonsumsi(
        draf: const DrafProduk(
          nama: 'Teh Manis Botol',
          takaranJumlah: 350,
          takaranSatuan: 'ml',
          gulaG: 18,
          natriumMg: 40,
          lemakTotalG: 0,
          lemakJenuhG: 0,
        ),
        jumlahSajian: 1,
        waktuLokal: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(
          nama: 'Teh Kurang Manis',
          takaranJumlah: 250,
          takaranSatuan: 'ml',
          gulaG: 8,
          natriumMg: 20,
          lemakTotalG: 0,
          lemakJenuhG: 0,
        ),
        jumlahSajian: 1,
        waktuLokal: DateTime.now().subtract(const Duration(days: 1)),
      );

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Bandingkan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bandingkan'));
      await t.pumpAndSettle();

      expect(find.text('Tambah produk ketiga'), findsNothing);

      // Pilih A lewat pencarian
      await t.tap(find.text('Pilih produk A'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Manis Botol');
      await t.pumpAndSettle();
      await t.tap(find.text('Teh Manis Botol'));
      await t.pumpAndSettle();

      // Pilih B
      await t.tap(find.text('Pilih produk B'));
      await t.pumpAndSettle();
      await t.tap(find.text('Teh Kurang Manis'));
      await t.pumpAndSettle();

      expect(find.text('B · pilihan lebih ringan'), findsOneWidget);
      expect(find.text('Dibandingkan per sajian label.'), findsOneWidget);
      expect(find.text('B lebih ringan 10 g gula. Itu 20% dari jatah gula harianmu.'), findsOneWidget);
      expect(find.textContaining('sehat', findRichText: true), findsNothing);
      expect(find.text('Tambah produk ketiga'), findsNothing);

      // Catat B dengan porsi 1
      await t.tap(find.text('Catat B'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Catat'));
      await t.pumpAndSettle();
      expect(find.text('Tercatat!'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      final hariIni = await repo.ringkasanHari(DateTime.now());
      expect(hariIni.totalGula, 8);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('masuk dari Produk saya dengan pilih 2 langsung menampilkan perbandingan A & B', (t) async {
      _layarSempit(t);
      final repo = getIt<AsupanRepository>();
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Susu Cokelat', gulaG: 14, natriumMg: 90, lemakTotalG: 5),
        jumlahSajian: 1,
        waktuLokal: DateTime.now(),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Susu Tawar', gulaG: 14, natriumMg: 80, lemakTotalG: 5),
        jumlahSajian: 1,
        waktuLokal: DateTime.now(),
      );

      await t.pumpWidget(JeliLabelApp(awal: '/produk'));
      await t.pumpAndSettle();

      await t.tap(find.text('Bandingkan'));
      await t.pumpAndSettle();
      expect(find.text('Pilih 2 produk untuk dibandingkan (0/2)'), findsOneWidget);

      await t.tap(find.text('Susu Cokelat'));
      await t.tap(find.text('Susu Tawar'));
      await t.pumpAndSettle();

      await t.tap(find.text('Bandingkan A & B'));
      await t.pumpAndSettle();

      expect(find.text('Gula keduanya sama.'), findsOneWidget);
      expect(find.text('Catat A'), findsOneWidget);
      expect(find.text('Catat B'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
