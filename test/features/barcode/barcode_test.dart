import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/barcode/data/pemindai_barcode_channel.dart';
import 'package:jelilabel/features/barcode/domain/pemindai_barcode.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PemindaiBarcodeMock implements PemindaiBarcode {
  _PemindaiBarcodeMock(this.handler);

  Future<HasilPindaiBarcode> Function() handler;
  int dipanggil = 0;

  @override
  Future<HasilPindaiBarcode> pindai() {
    dipanggil++;
    return handler();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  tearDown(() async {
    await resetDependensi();
  });

  group('PemindaiBarcodeChannel', () {
    test('memetakan string mentah, batal (null), dan galat tidak_tersedia dari MethodChannel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = PemindaiBarcodeChannel.channel;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      Object? respons = '8991002101234';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pindai');
        if (respons is PlatformException) throw respons;
        return respons;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      const pemindai = PemindaiBarcodeChannel();

      expect(await pemindai.pindai(), const HasilPindaiBarcode.berhasil('8991002101234'));

      respons = null;
      expect(await pemindai.pindai(), const HasilPindaiBarcode.batal());

      respons = '   ';
      expect(await pemindai.pindai(), const HasilPindaiBarcode.batal());

      respons = PlatformException(code: 'tidak_tersedia', message: 'Modul belum siap');
      expect(await pemindai.pindai(), const HasilPindaiBarcode.tidakTersedia());
    });
  });

  group('Alur Barcode di Beranda', () {
    testWidgets('ditemukan: tampil lembar F7, dialog porsi mencatat asupan tanpa mengurangi kuota (320 px)', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final mock = _PemindaiBarcodeMock(() async => const HasilPindaiBarcode.berhasil('8991002101234'));
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiBarcode: mock);

      final repo = getIt<AsupanRepository>();
      await repo.simpanKonsumsi(
        draf: const DrafProduk(
          nama: 'Teh Manis Botol',
          takaranJumlah: 350,
          takaranSatuan: 'ml',
          gulaG: 18,
          natriumMg: 600,
          lemakTotalG: 0,
          barcode: '8991002101234',
        ),
        jumlahSajian: 1,
        waktuLokal: DateTime.now().subtract(const Duration(days: 1)),
      );

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Barcode'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barcode'));
      await t.pumpAndSettle();

      expect(find.text('DITEMUKAN DI PRODUK SAYA'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Teh Manis Botol')), findsOneWidget);
      expect(find.text('350 ml'), findsOneWidget);
      expect(find.text('18 g gula · 600 mg natrium · 0 g lemak per sajian'), findsOneWidget);
      expect(find.text('Catat 1 porsi'), findsOneWidget);

      await t.tap(find.text('Catat 1 porsi'));
      await t.pumpAndSettle();
      await t.tap(find.text('2'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Catat'));
      await t.pumpAndSettle();

      expect(find.text('Tercatat!'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      expect(find.text('36 g / 50 g', findRichText: true), findsOneWidget);
      expect(find.text('Sisa 5 dari 5 minggu ini'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tidak ditemukan -> Foto label gizi memakai kuota dan menyimpan barcode bersama produk baru',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final mock = _PemindaiBarcodeMock(() async => const HasilPindaiBarcode.berhasil('8990000111222'));
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiBarcode: mock);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Barcode'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barcode'));
      await t.pumpAndSettle();

      expect(find.text('Produk baru buat Nuri'), findsOneWidget);
      expect(find.text('Foto labelnya sekali. Lain kali cukup barcode, tanpa kuota.'), findsOneWidget);
      expect(find.text('Foto label gizi'), findsOneWidget);
      expect(find.text('Isi manual'), findsAtLeastNWidgets(1));

      await t.tap(find.text('Foto label gizi'));
      await t.pump();
      expect(find.text('Nuri sedang membaca labelnya...'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      expect(find.text('Cek hasil pindai'), findsOneWidget);
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      // Kuota pindai berkurang 1 dan produk tersimpan dengan barcode
      expect(find.text('Sisa 4 dari 5 minggu ini'), findsOneWidget);
      final tersimpan = await getIt<AsupanRepository>().cariProdukByBarcode('8990000111222');
      expect(tersimpan, isNotNull);
      expect(tersimpan!.nama, 'Susu UHT Cokelat');
      expect(tersimpan.barcode, '8990000111222');

      // Pindai barcode yang sama lagi -> langsung ditemukan, tanpa memakai kuota
      await t.ensureVisible(find.text('Barcode'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barcode'));
      await t.pumpAndSettle();
      expect(find.text('DITEMUKAN DI PRODUK SAYA'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Susu UHT Cokelat')), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tidak ditemukan -> Isi manual membawa barcode ke draf dan menyimpannya saat Simpan', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final mock = _PemindaiBarcodeMock(() async => const HasilPindaiBarcode.berhasil('8995555666777'));
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiBarcode: mock);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Barcode'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barcode'));
      await t.pumpAndSettle();

      // Ketuk "Isi manual" di dalam lembar modal (elemen terakhir di tree)
      await t.tap(find.text('Isi manual').last);
      await t.pumpAndSettle();

      expect(find.text('Batal'), findsOneWidget);
      final isian = find.byType(TextField);
      await t.enterText(isian.at(0), 'Kopi Kaleng');
      await t.enterText(isian.at(1), '14');
      await t.pump();
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      final tersimpan = await getIt<AsupanRepository>().cariProdukByBarcode('8995555666777');
      expect(tersimpan, isNotNull);
      expect(tersimpan!.nama, 'Kopi Kaleng');
      expect(tersimpan.gulaG, 14);
      expect(find.text('Sisa 5 dari 5 minggu ini'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('batal memindai kembali tanpa pesan galat dan modul tidak tersedia menampilkan snackbar',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      var hasil = const HasilPindaiBarcode.batal();
      final mock = _PemindaiBarcodeMock(() async => hasil);
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiBarcode: mock);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Barcode'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barcode'));
      await t.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('DITEMUKAN DI PRODUK SAYA'), findsNothing);
      expect(find.text('Produk baru buat Nuri'), findsNothing);

      hasil = const HasilPindaiBarcode.tidakTersedia();
      await t.tap(find.text('Barcode'));
      await t.pumpAndSettle();

      expect(find.text('Pemindai barcode belum tersedia di HP ini.'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tombol Barcode terkunci selama pemindai terbuka sehingga ketuk ganda tidak memanggil dua kali',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final completer = Completer<HasilPindaiBarcode>();
      final mock = _PemindaiBarcodeMock(() => completer.future);
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, pemindaiBarcode: mock);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Barcode'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barcode'));
      await t.pump();
      await t.tap(find.text('Barcode'));
      await t.pump();

      expect(mock.dipanggil, 1);

      completer.complete(const HasilPindaiBarcode.batal());
      await t.pumpAndSettle();

      // Setelah selesai, tombol aktif lagi
      await t.tap(find.text('Barcode'));
      await t.pump();
      expect(mock.dipanggil, 2);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
