import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/bagikan/data_kartu_bagikan.dart';
import 'package:jelilabel/features/bagikan/kartu_bagikan.dart';
import 'package:jelilabel/features/bagikan/layanan_bagikan.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _LayananBagikanMock implements LayananBagikan {
  Uint8List? pngTerakhir;
  String? namaBerkasTerakhir;
  int jumlahPanggil = 0;

  @override
  Future<void> bagikanGambar({
    required Uint8List pngBytes,
    required String namaBerkas,
    String? teks,
  }) async {
    jumlahPanggil++;
    pngTerakhir = pngBytes;
    namaBerkasTerakhir = namaBerkas;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('DataKartuBagikan', () {
    test('menghitung sendok makan gula dan persen batas Kemenkes 50 g', () {
      const data = DataKartuBagikan(
        namaProduk: 'Teh Manis Botol',
        labelPorsi: '1 sajian',
        gulaG: 18,
        natriumMg: 600,
      );
      final info = data.info;
      expect(info.teksAngka, '1,5');
      expect(info.satuanSendok, 'sendok makan gula');
      expect(info.teksPersen, '36% dari batas gula harian Kemenkes (50 g)');
    });

    test('memakai ½ untuk 6,25 g dan < ½ untuk 2 g gula', () {
      const setengah = DataKartuBagikan(namaProduk: 'A', labelPorsi: '1 sajian', gulaG: 6.25);
      expect(setengah.info.teksAngka, '½');
      expect(setengah.info.satuanSendok, 'sendok makan gula');

      const kurang = DataKartuBagikan(namaProduk: 'B', labelPorsi: '1 sajian', gulaG: 2);
      expect(kurang.info.teksAngka, '< ½');
      expect(kurang.info.satuanSendok, 'sendok makan gula');
    });

    test('fallback ke natrium (sendok teh garam) bila gula null', () {
      const data = DataKartuBagikan(
        namaProduk: 'Keripik Asin',
        labelPorsi: '1 sajian',
        gulaG: null,
        natriumMg: 1000,
      );
      final info = data.info;
      expect(info.teksAngka, '½');
      expect(info.satuanSendok, 'sendok teh garam');
      expect(info.teksPersen, '50% dari batas natrium harian Kemenkes (2000 mg)');
    });
  });

  group('LembarBagikan dan alur Bagikan', () {
    late _LayananBagikanMock mockBagikan;

    setUp(() async {
      mockBagikan = _LayananBagikanMock();
      await siapkanDependensi(
        lokasiDb: inMemoryDatabasePath,
        layananBagikan: mockBagikan,
      );
    });

    tearDown(() async {
      await resetDependensi();
    });

    testWidgets('LembarBagikan merender PNG dari RepaintBoundary dan memanggil LayananBagikan tanpa tombol Simpan (320 px)',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      const data = DataKartuBagikan(
        namaProduk: 'Teh Manis Botol',
        labelPorsi: '1 sajian',
        gulaG: 18,
      );

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => tampilkanLembarBagikan(context, data),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Buka'));
      await t.pumpAndSettle();

      expect(find.text('Bagikan ke teman'), findsOneWidget);
      expect(find.text('Teh Manis Botol'), findsOneWidget);
      expect(find.text('setara'), findsOneWidget);
      expect(find.text('1,5'), findsOneWidget);
      expect(find.text('sendok makan gula'), findsOneWidget);
      expect(find.text('sendok teh gula'), findsNothing);
      expect(find.text('36% dari batas gula harian Kemenkes (50 g)'), findsOneWidget);
      expect(find.text('Dicek dengan JeliLabel'), findsOneWidget);
      expect(find.text('Gambar dibuat di HP. Foto label tidak ikut dibagikan.'), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);

      await t.ensureVisible(find.text('Bagikan'));
      await t.tap(find.text('Bagikan'));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pumpAndSettle();

      expect(mockBagikan.jumlahPanggil, 1);
      expect(mockBagikan.namaBerkasTerakhir, 'jelilabel-kartu.png');
      expect(mockBagikan.pngTerakhir, isNotNull);
      expect(mockBagikan.pngTerakhir!.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(t.takeException(), isNull);
    });

    testWidgets('Bagikan dari lembar detail Riwayat dan layar Produk saya membuka kartu yang sesuai', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final repo = getIt<AsupanRepository>();
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Keripik Gurih', gulaG: null, natriumMg: 1000),
        jumlahSajian: 1,
        waktuLokal: DateTime.now(),
      );

      // Dari detail Riwayat
      await t.pumpWidget(JeliLabelApp(awal: '/riwayat'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Keripik Gurih'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(find.text('Keripik Gurih'));
      await t.pumpAndSettle();
      await t.tap(find.text('Keripik Gurih'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Bagikan'));
      await t.tap(find.text('Bagikan'));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pumpAndSettle();
      expect(find.text('sendok teh garam'), findsOneWidget);
      expect(find.text('50% dari batas natrium harian Kemenkes (2000 mg)'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());

      // Dari Produk saya
      await t.pumpWidget(JeliLabelApp(awal: '/produk'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Bagikan Keripik Gurih'));
      await t.pumpAndSettle();
      expect(find.text('Bagikan ke teman'), findsOneWidget);
      expect(find.text('sendok teh garam'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
