import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/rapor/rapor_cubit.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('Rapor mingguan', () {
    late DateTime sekarang;

    setUp(() async {
      // Minggu, 22 Nov 2026 (Senin 16 Nov s.d. Minggu 22 Nov)
      sekarang = DateTime(2026, 11, 22, 10, 0);
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, jam: () => sekarang);
    });

    tearDown(() async {
      await resetDependensi();
    });

    test('RaporCubit menghitung hari di bawah batas, hari kosong, perbandingan minggu lalu, dan penyumbang teratas',
        () async {
      final repo = getIt<AsupanRepository>();
      // Minggu lalu (9-15 Nov): 1 hari di bawah batas, 1 hari lewat batas
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Air Gula', gulaG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 10, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Sirup', gulaG: 65),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 11, 9),
      );

      // Minggu ini (16-22 Nov): 3 hari di bawah batas (16, 17, 19), 1 hari lewat batas (18), 3 hari kosong
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis', gulaG: 20, natriumMg: 400, lemakTotalG: 4),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 16, 8),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis', gulaG: 20, natriumMg: 400, lemakTotalG: 4),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 17, 8),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Minuman Boba', gulaG: 60, natriumMg: 200, lemakTotalG: 12),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 18, 8),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Roti', gulaG: 10, natriumMg: 200, lemakTotalG: 4),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 19, 8),
      );

      final cubit = getIt<RaporCubit>();
      await cubit.muat();

      expect(cubit.state.mingguIni, isTrue);
      expect(cubit.state.bisaKeMingguBerikutnya, isFalse);
      expect(cubit.state.ringkasan.hariGulaDiBawahBatas, 3);
      expect(cubit.state.ringkasan.hariKosong, 3);
      expect(cubit.state.selisihDariMingguLalu, 2);
      expect(cubit.state.teksPerbandingan, 'Naik 2 hari dari minggu lalu.');
      expect(cubit.state.penyumbang.first.nama, 'Minuman Boba');
      expect(cubit.state.penyumbang[1].nama, 'Teh Manis');
      expect(cubit.state.penyumbang[1].jumlahKali, 2);

      // Navigasi ke minggu lalu -> Turun / Sama
      await cubit.mingguSebelumnya();
      expect(cubit.state.mingguIni, isFalse);
      expect(cubit.state.bisaKeMingguBerikutnya, isTrue);
      expect(cubit.state.ringkasan.hariGulaDiBawahBatas, 1);
      expect(cubit.state.teksPerbandingan, 'Minggu lalu belum ada catatan.');

      await cubit.close();
    });

    testWidgets('RaporPage minggu kosong menampilkan Nuri 01, pesan kosong, dan tombol ke Beranda (320 px)',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(JeliLabelApp(awal: '/rapor'));
      await t.pumpAndSettle();

      expect(find.text('16 sampai 22 November'), findsOneWidget);
      expect(find.text('Rapor minggu ini'), findsOneWidget);
      expect(find.text('Belum ada catatan minggu ini'), findsOneWidget);
      expect(find.text('Ke Beranda'), findsOneWidget);
      expect(find.bySemanticsLabel('Nuri mengintip'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.ensureVisible(find.text('Ke Beranda'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ke Beranda'));
      await t.pumpAndSettle();
      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('RaporPage minggu berisi menampilkan hari di bawah batas, rata-rata, penyumbang, dan tanpa Bagikan',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final repo = getIt<AsupanRepository>();
      // Minggu lalu: 4 hari di bawah batas
      for (var d = 9; d <= 12; d++) {
        await repo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Susu', gulaG: 10),
          jumlahSajian: 1,
          waktuLokal: DateTime(2026, 11, d, 9),
        );
      }
      // Minggu ini: 3 hari di bawah batas -> Turun 1 hari dari minggu lalu, 4 hari belum ada catatan
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis Botol', gulaG: 20, natriumMg: 400, lemakTotalG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 16, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis Botol', gulaG: 20, natriumMg: 400, lemakTotalG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 17, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Roti Cokelat', gulaG: 10, natriumMg: 100, lemakTotalG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 18, 9),
      );

      await t.pumpWidget(JeliLabelApp(awal: '/rapor'));
      await t.pumpAndSettle();

      expect(find.text('3 dari 7 hari', findRichText: true), findsOneWidget);
      expect(find.textContaining('Turun 1 hari dari minggu lalu'), findsOneWidget);
      expect(find.text('4 hari belum ada catatan'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Teh Manis Botol'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Penyumbang gula terbesar'), findsOneWidget);
      expect(find.text('Teh Manis Botol'), findsOneWidget);
      expect(find.text('80% · 2 kali'), findsOneWidget);
      expect(find.byTooltip('Bagikan rapor'), findsNothing);
      expect(find.text('Bagikan'), findsNothing);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
