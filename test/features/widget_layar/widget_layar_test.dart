import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/barcode/domain/pemindai_barcode.dart';
import 'package:jelilabel/features/profil/data/profil_repository.dart';
import 'package:jelilabel/features/profil/domain/profil_batas.dart';
import 'package:jelilabel/features/widget_layar/domain/data_widget_layar.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PemasokWidgetMock implements PemasokWidgetLayar {
  final List<DataWidgetLayar> riwayat = [];
  final StreamController<Uri?> controller = StreamController<Uri?>.broadcast();

  @override
  Stream<Uri?> get aliranKetuk => controller.stream;

  @override
  Future<void> perbarui(DataWidgetLayar data) async {
    riwayat.add(data);
  }

  @override
  Future<Uri?> tautanAwal() async => null;
}

class _PemindaiBarcodeMock implements PemindaiBarcode {
  int jumlahPanggil = 0;

  @override
  Future<HasilPindaiBarcode> pindai() async {
    jumlahPanggil++;
    return const HasilPindaiBarcode.batal();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('hitungDataWidgetLayar (ISSUE-22 A)', () {
    final waktu = DateTime(2026, 11, 27, 8, 10);

    test('tanpa catatan menghasilkan adaCatatan false dan waktu diperbarui', () {
      final data = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(),
        profil: ProfilPengguna.kosong,
        waktu: waktu,
      );
      expect(data.adaCatatan, isFalse);
      expect(data.teksSisa, isEmpty);
      expect(data.labelStatus, isEmpty);
      expect(data.diperbarui, 'diperbarui 08.10');
    });

    test('menghitung sisa zat fokus gula beserta status Aman, Hampir batas, Lewat batas', () {
      final aman = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalGula: 18, jumlahCatatan: 1),
        profil: const ProfilPengguna(fokus: FokusZat.gula),
        waktu: waktu,
      );
      expect(aman.adaCatatan, isTrue);
      expect(aman.teksSisa, 'Gula sisa 32 g');
      expect(aman.labelStatus, 'Aman');
      expect(aman.kodeStatus, 'aman');
      expect(aman.persenTerpakai, 36);
      expect(aman.diperbarui, 'diperbarui 08.10');

      final hampir = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalGula: 40, jumlahCatatan: 2),
        profil: const ProfilPengguna(fokus: FokusZat.gula),
        waktu: waktu,
      );
      expect(hampir.teksSisa, 'Gula sisa 10 g');
      expect(hampir.labelStatus, 'Hampir batas');
      expect(hampir.kodeStatus, 'hampir_batas');

      final lewat = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalGula: 60, jumlahCatatan: 2),
        profil: const ProfilPengguna(fokus: FokusZat.gula),
        waktu: waktu,
      );
      expect(lewat.teksSisa, 'Gula lewat 10 g');
      expect(lewat.labelStatus, 'Lewat batas');
      expect(lewat.kodeStatus, 'lewat_batas');
      expect(lewat.persenTerpakai, 100);

      final lewatNatrium = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalNatrium: 2250, jumlahCatatan: 1),
        profil: const ProfilPengguna(fokus: FokusZat.natrium),
        waktu: waktu,
      );
      expect(lewatNatrium.teksSisa, 'Natrium lewat 250 mg');
      expect(lewatNatrium.labelStatus, 'Lewat batas');

      final lewatLemak = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalLemak: 72, jumlahCatatan: 1),
        profil: const ProfilPengguna(fokus: FokusZat.lemak),
        waktu: waktu,
      );
      expect(lewatLemak.teksSisa, 'Lemak lewat 5 g');
      expect(lewatLemak.labelStatus, 'Lewat batas');
    });

    test('mengikuti zat fokus natrium dan lemak dari profil aktif', () {
      final natrium = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalNatrium: 1520, jumlahCatatan: 1),
        profil: const ProfilPengguna(fokus: FokusZat.natrium),
        waktu: waktu,
      );
      expect(natrium.teksSisa, 'Natrium sisa 480 mg');
      expect(natrium.labelStatus, 'Hampir batas');

      final lemak = hitungDataWidgetLayar(
        ringkasan: const RingkasanHari(totalLemak: 20, jumlahCatatan: 1),
        profil: const ProfilPengguna(fokus: FokusZat.lemak),
        waktu: waktu,
      );
      expect(lemak.teksSisa, 'Lemak sisa 47 g');
      expect(lemak.labelStatus, 'Aman');
    });
  });

  group('Integrasi AsupanCubit -> PemasokWidgetLayar lewat get_it', () {
    late _PemasokWidgetMock widgetMock;
    late DateTime sekarang;

    setUp(() async {
      sekarang = DateTime(2026, 11, 27, 8, 10);
      widgetMock = _PemasokWidgetMock();
      await siapkanDependensi(
        lokasiDb: inMemoryDatabasePath,
        jam: () => sekarang,
        pemasokWidgetLayar: widgetMock,
      );
    });

    tearDown(() async {
      await resetDependensi();
      await widgetMock.controller.close();
    });

    test('mengirim pembaruan saat muat, simpan, ubahPorsi, dan hapus', () async {
      final cubit = getIt<AsupanCubit>();
      await cubit.muat();
      expect(widgetMock.riwayat.last.adaCatatan, isFalse);

      await cubit.simpan(const DrafProduk(nama: 'Teh Manis', gulaG: 18), 1);
      expect(widgetMock.riwayat.last.adaCatatan, isTrue);
      expect(widgetMock.riwayat.last.teksSisa, 'Gula sisa 32 g');
      expect(widgetMock.riwayat.last.labelStatus, 'Aman');

      final baris = cubit.state.daftar.single;
      await cubit.ubahPorsi(baris.id, 2.5);
      expect(widgetMock.riwayat.last.teksSisa, 'Gula sisa 5 g');
      expect(widgetMock.riwayat.last.labelStatus, 'Hampir batas');

      await cubit.hapus(cubit.state.daftar.single);
      expect(widgetMock.riwayat.last.adaCatatan, isFalse);

      await cubit.close();
    });

    test('memakai fokus zat profil aktif', () async {
      await getIt<ProfilRepository>().simpanProfil(
        const ProfilPengguna(nama: 'Ibu', fokus: FokusZat.natrium),
      );
      final cubit = getIt<AsupanCubit>();
      await cubit.simpan(const DrafProduk(nama: 'Keripik', natriumMg: 400), 1);
      expect(widgetMock.riwayat.last.teksSisa, 'Natrium sisa 1600 mg');
      expect(widgetMock.riwayat.last.labelStatus, 'Aman');
      await cubit.close();
    });
  });

  group('Deep link widget layar utama', () {
    late _PemasokWidgetMock widgetMock;
    late _PemindaiBarcodeMock barcodeMock;

    setUp(() async {
      widgetMock = _PemasokWidgetMock();
      barcodeMock = _PemindaiBarcodeMock();
      await siapkanDependensi(
        lokasiDb: inMemoryDatabasePath,
        pemasokWidgetLayar: widgetMock,
        pemindaiBarcode: barcodeMock,
      );
    });

    tearDown(() async {
      await resetDependensi();
      await widgetMock.controller.close();
    });

    testWidgets('tautan jelilabel://pindai membuka layar pindai dan jelilabel://barcode memanggil barcode', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        JeliLabelApp(
          awal: '/beranda',
          widgetLayar: widgetMock,
          tautanWidgetAwal: Uri.parse('jelilabel://pindai'),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('Nuri sedang membaca labelnya...'), findsOneWidget);

      await t.tap(find.byTooltip('Batal'));
      await t.pumpAndSettle();
      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);

      widgetMock.controller.add(Uri.parse('jelilabel://barcode'));
      await t.pump();
      await t.pumpAndSettle();
      expect(barcodeMock.jumlahPanggil, 1);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('rute / dan lokasi tak dikenal mengarah ke Beranda, dan deeplink Flutter dinonaktifkan di manifest',
        (t) async {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
      expect(manifest, contains('android:value="false"'));

      for (final ruteAwal in const ['/', '/rute-tidak-dikenal', '/jelilabel://barcode/']) {
        await t.pumpWidget(JeliLabelApp(awal: ruteAwal));
        await t.pumpAndSettle();

        expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.textContaining('Page Not Found'), findsNothing);
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
