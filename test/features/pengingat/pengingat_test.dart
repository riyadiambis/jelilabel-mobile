import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pengingat/domain/layanan_notifikasi.dart';
import 'package:jelilabel/features/pengingat/domain/pengaturan_pengingat.dart';
import 'package:jelilabel/features/pengingat/presentation/pengingat_cubit.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _JadwalTercatat {
  const _JadwalTercatat({
    required this.id,
    required this.judul,
    required this.isi,
    required this.waktuLokal,
    required this.ulangiHarian,
    this.payload,
  });

  final int id;
  final String judul;
  final String isi;
  final DateTime waktuLokal;
  final bool ulangiHarian;
  final String? payload;
}

class _LayananNotifikasiMock implements LayananNotifikasi {
  bool izinDiberikan = true;
  int jumlahMintaIzin = 0;
  final List<_JadwalTercatat> terjadwal = [];
  final List<int> dibatalkan = [];
  void Function(String?)? onKetuk;

  @override
  Future<void> inisialisasi({void Function(String? payload)? onKetuk}) async {
    this.onKetuk = onKetuk;
  }

  @override
  Future<String?> payloadPeluncuranAwal() async => null;

  @override
  Future<bool> mintaIzinNotifikasi() async {
    jumlahMintaIzin++;
    return izinDiberikan;
  }

  @override
  Future<void> jadwalkanHarianInexact({
    required int id,
    required String judul,
    required String isi,
    required DateTime waktuLokal,
    required bool ulangiHarian,
    String? payload,
  }) async {
    terjadwal.add(
      _JadwalTercatat(
        id: id,
        judul: judul,
        isi: isi,
        waktuLokal: waktuLokal,
        ulangiHarian: ulangiHarian,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> batalkan(int id) async {
    dibatalkan.add(id);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('hitungJadwalBerikutnya (ISSUE-22 B)', () {
    test('menjadwalkan hari ini bila belum lewat jam dan belum ada catatan', () {
      final hasil = hitungJadwalBerikutnya(
        sekarang: DateTime(2026, 11, 27, 10, 0),
        jam: 19,
        menit: 0,
        sudahAdaCatatanHariIni: false,
      );
      expect(hasil.waktu, DateTime(2026, 11, 27, 19, 0));
      expect(hasil.ulangiHarian, isTrue);
    });

    test('menjadwalkan besok bila jam hari ini sudah lewat', () {
      final hasil = hitungJadwalBerikutnya(
        sekarang: DateTime(2026, 11, 27, 19, 30),
        jam: 19,
        menit: 0,
        sudahAdaCatatanHariIni: false,
      );
      expect(hasil.waktu, DateTime(2026, 11, 28, 19, 0));
      expect(hasil.ulangiHarian, isTrue);
    });

    test('melewati hari ini bila hari itu sudah ada catatan', () {
      final hasil = hitungJadwalBerikutnya(
        sekarang: DateTime(2026, 11, 27, 10, 0),
        jam: 19,
        menit: 0,
        sudahAdaCatatanHariIni: true,
      );
      expect(hasil.waktu, DateTime(2026, 11, 28, 19, 0));
      expect(hasil.ulangiHarian, isFalse);
    });
  });

  group('PengingatCubit dan LayananNotifikasi mock lewat get_it', () {
    late _LayananNotifikasiMock notifMock;
    late DateTime sekarang;

    setUp(() async {
      sekarang = DateTime(2026, 11, 27, 10, 0);
      notifMock = _LayananNotifikasiMock();
      await siapkanDependensi(
        lokasiDb: inMemoryDatabasePath,
        jam: () => sekarang,
        layananNotifikasi: notifMock,
      );
    });

    tearDown(() async {
      await resetDependensi();
    });

    test('default mati (19.00) dan tidak meminta izin sebelum sakelar dinyalakan', () async {
      final cubit = getIt<PengingatCubit>();
      await cubit.muat();
      expect(cubit.state.aktif, isFalse);
      expect(cubit.state.jamTeks, '19.00');
      expect(notifMock.jumlahMintaIzin, 0);
      expect(notifMock.terjadwal, isEmpty);
      await cubit.close();
    });

    test('izin ditolak mengembalikan sakelar ke mati dan menandai izinDitolak', () async {
      notifMock.izinDiberikan = false;
      final cubit = getIt<PengingatCubit>();
      await cubit.muat();

      final ok = await cubit.ubahAktif(true);
      expect(ok, isFalse);
      expect(notifMock.jumlahMintaIzin, 1);
      expect(cubit.state.aktif, isFalse);
      expect(cubit.state.izinDitolak, isTrue);
      expect(notifMock.terjadwal, isEmpty);
      expect(notifMock.dibatalkan, contains(idNotifikasiPengingat));
      await cubit.close();
    });

    test('izin diterima menyalakan pengingat, menyimpan jam, memakai teks tetap, dan melewati hari bercatatan',
        () async {
      notifMock.izinDiberikan = true;
      final cubit = getIt<PengingatCubit>();
      await cubit.muat();

      final ok = await cubit.ubahAktif(true);
      expect(ok, isTrue);
      expect(cubit.state.aktif, isTrue);
      expect(notifMock.terjadwal.last.isi, 'Sudah catat jajanan hari ini? Nuri siap bantu.');
      expect(notifMock.terjadwal.last.waktuLokal, DateTime(2026, 11, 27, 19, 0));
      expect(notifMock.terjadwal.last.ulangiHarian, isTrue);

      await cubit.ubahJam(20, 15);
      expect(cubit.state.jamTeks, '20.15');
      expect(notifMock.terjadwal.last.waktuLokal, DateTime(2026, 11, 27, 20, 15));

      // Catat makanan hari ini -> jadwalkanUlang melewati hari ini (geser ke besok)
      await getIt<AsupanRepository>().simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 10),
        jumlahSajian: 1,
        waktuLokal: sekarang,
      );
      await cubit.jadwalkanUlang();
      expect(notifMock.terjadwal.last.waktuLokal, DateTime(2026, 11, 28, 20, 15));
      expect(notifMock.terjadwal.last.ulangiHarian, isFalse);
      await cubit.close();

      // Buka cubit baru -> jam & status bertahan dari SQLite
      final cubit2 = getIt<PengingatCubit>();
      await cubit2.muat();
      expect(cubit2.state.aktif, isTrue);
      expect(cubit2.state.jamTeks, '20.15');
      await cubit2.close();
    });
  });

  group('UI Profil > Pengingat dan ketuk notifikasi (320 px)', () {
    late _LayananNotifikasiMock notifMock;

    setUp(() async {
      notifMock = _LayananNotifikasiMock();
      await siapkanDependensi(
        lokasiDb: inMemoryDatabasePath,
        jam: () => DateTime(2026, 11, 27, 10, 0),
        layananNotifikasi: notifMock,
      );
    });

    tearDown(() async {
      await resetDependensi();
    });

    testWidgets('sakelar ditolak dan diterima serta ubah jam di lembar Pengingat tanpa overflow', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      notifMock.izinDiberikan = false;

      await t.pumpWidget(JeliLabelApp(awal: '/profil'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Pengingat'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pengingat'));
      await t.pumpAndSettle();

      expect(find.text('Pengingat harian'), findsOneWidget);
      expect(find.text('19.00'), findsOneWidget);
      expect(find.textContaining('Sudah catat jajanan hari ini? Nuri siap bantu.'), findsOneWidget);

      // Nyalakan saat izin ditolak -> sakelar tetap mati + teks penolakan tampil
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('Izin notifikasi ditolak. Bisa diubah di Pengaturan HP.'), findsOneWidget);

      // Izinkan -> sakelar menyala
      notifMock.izinDiberikan = true;
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Izin notifikasi ditolak. Bisa diubah di Pengaturan HP.'), findsNothing);

      // Ubah jam pengingat melalui TimePicker
      await t.tap(find.text('Jam pengingat'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      // Tutup lembar -> baris Pengingat menampilkan jam 19.00
      await t.tap(find.byTooltip('Tutup'));
      await t.pumpAndSettle();
      expect(find.text('19.00'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ketuk notifikasi mengarahkan ke Beranda', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final ketukCtrl = StreamController<String?>.broadcast();
      addTearDown(ketukCtrl.close);

      await t.pumpWidget(
        JeliLabelApp(
          awal: '/profil',
          aliranKetukNotifikasi: ketukCtrl.stream,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tambah anggota keluarga'), findsOneWidget);

      ketukCtrl.add('/beranda');
      await t.pumpAndSettle();
      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
