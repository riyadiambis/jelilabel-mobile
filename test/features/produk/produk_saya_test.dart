import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  testWidgets('ProdukSayaPage kosong menampilkan Nuri 01 dan tanpa batas 10 produk atau Plus (320 px)', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(JeliLabelApp(awal: '/produk'));
    await t.pumpAndSettle();

    expect(find.text('Produk saya'), findsOneWidget);
    expect(find.bySemanticsLabel('Nuri mengintip'), findsOneWidget);
    expect(find.text('Produk yang kamu catat muncul di sini'), findsOneWidget);
    expect(find.textContaining('10'), findsNothing);
    expect(find.textContaining('Plus'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ProdukSayaPage mengurutkan Sering vs Terbaru, tampil "-" untuk null, dan Catat menyimpan nilai x porsi',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final repo = getIt<AsupanRepository>();
    final kemarin = DateTime.now().subtract(const Duration(days: 1));
    final duaHariLalu = DateTime.now().subtract(const Duration(days: 2));

    // Teh Manis: 2 kali (lebih sering, tapi lebih lama)
    final k1 = await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Teh Manis', gulaG: 18, natriumMg: 600, lemakTotalG: null),
      jumlahSajian: 1,
      waktuLokal: duaHariLalu,
    );
    await repo.catatUlang(k1, waktuLokal: duaHariLalu.add(const Duration(hours: 2)));

    // Kopi Susu: 1 kali (lebih baru)
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Kopi Susu', gulaG: 14, natriumMg: 120, lemakTotalG: 5),
      jumlahSajian: 1,
      waktuLokal: kemarin,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/produk'));
    await t.pumpAndSettle();

    // Default Sering: Teh Manis di atas Kopi Susu
    final posTehSering = t.getTopLeft(find.text('Teh Manis')).dy;
    final posKopiSering = t.getTopLeft(find.text('Kopi Susu')).dy;
    expect(posTehSering, lessThan(posKopiSering));
    expect(find.text('18 g gula · 600 mg natrium · - g lemak · 2 kali'), findsOneWidget);
    expect(find.text('14 g gula · 120 mg natrium · 5 g lemak · 1 kali'), findsOneWidget);

    // Ubah ke Terbaru: Kopi Susu di atas Teh Manis
    await t.tap(find.text('Terbaru'));
    await t.pumpAndSettle();
    final posKopiTerbaru = t.getTopLeft(find.text('Kopi Susu')).dy;
    final posTehTerbaru = t.getTopLeft(find.text('Teh Manis')).dy;
    expect(posKopiTerbaru, lessThan(posTehTerbaru));

    // Catat Kopi Susu (urutan pertama di Terbaru) dengan porsi 2 -> simpan nilai produk x 2 untuk hari ini
    await t.tap(find.text('Catat').first);
    await t.pumpAndSettle();
    await t.tap(find.text('2'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Catat'));
    await t.pumpAndSettle();

    expect(find.text('Kopi Susu dicatat untuk hari ini'), findsOneWidget);
    expect(find.text('14 g gula · 120 mg natrium · 5 g lemak · 2 kali'), findsOneWidget);
    final ringkasanHariIni = await repo.ringkasanHari(DateTime.now());
    expect(ringkasanHariIni.totalGula, 28);
    expect(ringkasanHariIni.totalNatrium, 240);
    expect(ringkasanHariIni.totalLemak, 10);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Beranda: chip Catat ulang sekali ketuk tersembunyi saat kosong dan mencatat porsi 1 saat diketuk',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    // Kosong: chip tersembunyi
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.text('Catat ulang sekali ketuk'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());

    // Tambah 4 produk di hari kemarin dengan frekuensi berbeda
    final repo = getIt<AsupanRepository>();
    final kemarin = DateTime.now().subtract(const Duration(days: 1));
    for (var i = 0; i < 4; i++) {
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Air Gula', gulaG: 15, natriumMg: 10),
        jumlahSajian: 1,
        waktuLokal: kemarin,
      );
    }
    for (var i = 0; i < 3; i++) {
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Kopi Kaleng', gulaG: 10),
        jumlahSajian: 1,
        waktuLokal: kemarin,
      );
    }
    for (var i = 0; i < 2; i++) {
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Roti Keju', gulaG: 8),
        jumlahSajian: 1,
        waktuLokal: kemarin,
      );
    }
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Biskuit', gulaG: 5),
      jumlahSajian: 1,
      waktuLokal: kemarin,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();

    expect(find.text('Catat ulang sekali ketuk'), findsOneWidget);
    expect(find.text('Air Gula'), findsOneWidget);
    expect(find.text('Kopi Kaleng'), findsOneWidget);
    expect(find.text('Roti Keju'), findsOneWidget);
    expect(find.text('Biskuit'), findsNothing);

    await t.ensureVisible(find.text('Air Gula'));
    await t.pumpAndSettle();
    await t.tap(find.text('Air Gula'));
    await t.pumpAndSettle();

    expect(find.text('Tercatat!'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    expect(find.text('15 g / 50 g', findRichText: true), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ProdukSayaPage menampilkan lencana Nutri-Level hanya untuk produk ml, tidak untuk g (320 px)',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final repo = getIt<AsupanRepository>();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(
        nama: 'Minuman Isotonik',
        takaranJumlah: 250,
        takaranSatuan: 'ml',
        gulaG: 12.5,
        natriumMg: 150,
        lemakJenuhG: 0,
      ),
      jumlahSajian: 1,
      waktuLokal: DateTime.now(),
    );
    await repo.simpanKonsumsi(
      draf: const DrafProduk(
        nama: 'Keripik Kentang',
        takaranJumlah: 30,
        takaranSatuan: 'g',
        gulaG: 1,
        natriumMg: 200,
        lemakJenuhG: 3,
      ),
      jumlahSajian: 1,
      waktuLokal: DateTime.now(),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/produk'));
    await t.pumpAndSettle();

    expect(find.text('Nutri-Level (perkiraan)'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });
}
