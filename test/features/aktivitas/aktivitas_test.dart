import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/core/format.dart';
import 'package:jelilabel/core/theme/warna.dart';
import 'package:jelilabel/features/aktivitas/domain/sesi_olahraga.dart';
import 'package:jelilabel/features/aktivitas/domain/sumber_aktivitas.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockSumberAktivitas implements SumberAktivitas {
  _MockSumberAktivitas({
    this.tersediaNilai = true,
    this.status = StatusHealthConnect.tersedia,
    this.diizinkanNilai = true,
    this.hasilMintaIzin = true,
    this.langkahPerHari = const {},
    this.daftarSesi = const [],
    this.lemparGalat = false,
  });

  bool tersediaNilai;
  StatusHealthConnect status;
  bool diizinkanNilai;
  bool hasilMintaIzin;
  Map<String, int> langkahPerHari;
  List<SesiOlahraga> daftarSesi;
  bool lemparGalat;

  int panggilMintaIzin = 0;
  int panggilBukaPlayStore = 0;

  @override
  Future<bool> tersedia() async {
    if (lemparGalat) throw StateError('galat tersedia');
    return tersediaNilai;
  }

  @override
  Future<StatusHealthConnect> statusPerangkat() async {
    if (lemparGalat) throw StateError('galat status');
    return status;
  }

  @override
  Future<bool> sudahDiizinkan() async {
    if (lemparGalat) throw StateError('galat izin');
    return diizinkanNilai;
  }

  @override
  Future<bool> mintaIzin() async {
    panggilMintaIzin++;
    if (lemparGalat) throw StateError('galat mintaIzin');
    if (hasilMintaIzin) diizinkanNilai = true;
    return hasilMintaIzin;
  }

  @override
  Future<void> bukaPlayStore() async {
    panggilBukaPlayStore++;
    if (lemparGalat) throw StateError('galat play store');
  }

  @override
  Future<int?> langkahHari(DateTime tanggal) async {
    if (lemparGalat) throw StateError('galat langkahHari');
    return langkahPerHari[tanggalLokal(tanggal)];
  }

  @override
  Future<Map<String, int>> langkahRentang(DateTime dari, DateTime sampai) async {
    if (lemparGalat) throw StateError('galat langkahRentang');
    final awal = tanggalLokal(dari);
    final akhir = tanggalLokal(sampai);
    return {
      for (final e in langkahPerHari.entries)
        if (e.key.compareTo(awal) >= 0 && e.key.compareTo(akhir) <= 0) e.key: e.value,
    };
  }

  @override
  Future<List<SesiOlahraga>> sesiOlahraga(DateTime dari, DateTime sampai) async {
    if (lemparGalat) throw StateError('galat sesiOlahraga');
    final awal = DateTime(dari.year, dari.month, dari.day);
    final akhir = DateTime(sampai.year, sampai.month, sampai.day).add(const Duration(days: 1));
    return daftarSesi
        .where((s) => !s.mulai.isBefore(awal) && s.mulai.isBefore(akhir))
        .toList();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late DateTime sekarang;

  setUp(() {
    // Minggu, 22 Nov 2026 (Senin 16 Nov s.d. Minggu 22 Nov)
    sekarang = DateTime(2026, 11, 22, 10, 0);
  });

  tearDown(() async {
    await resetDependensi();
  });

  test('format ribuan dan ringkasan SesiOlahraga sesuai spesifikasi', () {
    expect(ribuan(4210), '4.210');
    expect(ribuan(0), '0');
    expect(ribuan(999), '999');
    expect(ribuan(12500), '12.500');

    final jogging = SesiOlahraga(
      jenis: JenisOlahraga.jogging,
      mulai: DateTime(2026, 11, 22, 7, 15),
      durasi: const Duration(minutes: 32),
      jarakMeter: 4100,
    );
    expect(jogging.teksRingkasan, 'Jogging · 32 menit · 4,1 km');

    final jalan = SesiOlahraga(
      jenis: JenisOlahraga.jalan,
      mulai: DateTime(2026, 11, 22, 17, 0),
      durasi: const Duration(minutes: 15),
      jarakMeter: 850,
    );
    expect(jalan.teksRingkasan, 'Jalan · 15 menit · 850 m');

    final lainnya = SesiOlahraga(
      jenis: JenisOlahraga.lainnya,
      mulai: DateTime(2026, 11, 21, 18, 0),
      durasi: const Duration(minutes: 45),
    );
    expect(lainnya.teksRingkasan, 'Olahraga · 45 menit');
  });

  testWidgets('Beranda menampilkan baris langkah bila terhubung dan menyembunyikannya bila belum terhubung', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    // 1. Terhubung: tampil "Langkah hari ini: 4.210" tanpa target dan tanpa warna status
    final sumberTerhubung = _MockSumberAktivitas(
      langkahPerHari: {'2026-11-22': 4210},
    );
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: sumberTerhubung,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();

    expect(find.text('Langkah hari ini: 4.210'), findsOneWidget);
    expect(find.textContaining('target', findRichText: true), findsNothing);
    expect(t.takeException(), isNull);

    // Pastikan juga tampil saat ada catatan makanan hari ini
    await getIt<AsupanRepository>().simpanKonsumsi(
      draf: const DrafProduk(nama: 'Teh Manis', gulaG: 12),
      jumlahSajian: 1,
      waktuLokal: sekarang,
    );
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.text('Langkah hari ini: 4.210'), findsOneWidget);
    expect(t.takeException(), isNull);

    // 2. Belum terhubung: baris langkah disembunyikan
    await t.pumpWidget(const SizedBox.shrink());
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: _MockSumberAktivitas(
        diizinkanNilai: false,
        langkahPerHari: {'2026-11-22': 4210},
      ),
    );
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.textContaining('Langkah hari ini'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Riwayat menampilkan kartu sesi olahraga tanpa warna status', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final sumber = _MockSumberAktivitas(
      daftarSesi: [
        SesiOlahraga(
          jenis: JenisOlahraga.jogging,
          mulai: DateTime(2026, 11, 22, 7, 15),
          durasi: const Duration(minutes: 32),
          jarakMeter: 4100,
        ),
        SesiOlahraga(
          jenis: JenisOlahraga.jalan,
          mulai: DateTime(2026, 11, 21, 17, 30),
          durasi: const Duration(minutes: 20),
        ),
      ],
    );
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: sumber,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/riwayat'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Jogging · 32 menit · 4,1 km'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Jogging · 32 menit · 4,1 km'), findsOneWidget);
    expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);

    await t.scrollUntilVisible(
      find.text('Jalan · 20 menit'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Jalan · 20 menit'), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);

    // Tidak ada warna status gizi atau chip status pada kartu sesi olahraga
    final containerSesi = find.ancestor(
      of: find.text('Jogging · 32 menit · 4,1 km'),
      matching: find.byType(Container),
    );
    for (final c in t.widgetList<Container>(containerSesi)) {
      final dec = c.decoration;
      if (dec is BoxDecoration) {
        expect(dec.color, isNot(Warna.amanLatar));
        expect(dec.color, isNot(Warna.waspadaLatar));
        expect(dec.color, isNot(Warna.tinggiLatar));
      }
    }
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Rapor menampilkan petak keempat Langkah rata-rata minggu itu hanya bila terhubung', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final sumber = _MockSumberAktivitas(
      langkahPerHari: {
        '2026-11-16': 4000,
        '2026-11-18': 6000,
        '2026-11-22': 2630,
      },
    );
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: sumber,
    );
    await getIt<AsupanRepository>().simpanKonsumsi(
      draf: const DrafProduk(nama: 'Teh Manis', gulaG: 15, natriumMg: 200, lemakTotalG: 5),
      jumlahSajian: 1,
      waktuLokal: sekarang,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/rapor'));
    await t.pumpAndSettle();

    // (4000 + 6000 + 2630) / 3 = 4210
    await t.scrollUntilVisible(
      find.text('Langkah'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Langkah'), findsOneWidget);
    expect(find.text('4.210'), findsOneWidget);
    expect(t.takeException(), isNull);

    // Bila belum terhubung, petak Langkah tidak tampil
    await t.pumpWidget(const SizedBox.shrink());
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: _MockSumberAktivitas(diizinkanNilai: false),
    );
    await getIt<AsupanRepository>().simpanKonsumsi(
      draf: const DrafProduk(nama: 'Teh Manis', gulaG: 15, natriumMg: 200, lemakTotalG: 5),
      jumlahSajian: 1,
      waktuLokal: sekarang,
    );
    await t.pumpWidget(JeliLabelApp(awal: '/rapor'));
    await t.pumpAndSettle();

    expect(find.text('Langkah'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Profil menu Langkah dan olahraga menangani belum terpasang, minta izin, dan layar /aktivitas/izin',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    // 1. Belum terpasang -> penjelasan + tombol Buka Play Store
    final sumberBelumPasang = _MockSumberAktivitas(
      tersediaNilai: false,
      status: StatusHealthConnect.perluPasang,
      diizinkanNilai: false,
    );
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: sumberBelumPasang,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/profil'));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('Langkah dan olahraga'));
    await t.pumpAndSettle();
    expect(find.text('Langkah dan olahraga'), findsOneWidget);
    expect(find.text('Belum terhubung'), findsOneWidget);

    await t.tap(find.text('Langkah dan olahraga'));
    await t.pumpAndSettle();
    expect(find.text('Health Connect belum terpasang'), findsOneWidget);
    expect(find.text('Buka Play Store'), findsOneWidget);

    await t.tap(find.text('Buka Play Store'));
    await t.pumpAndSettle();
    expect(sumberBelumPasang.panggilBukaPlayStore, 1);
    expect(t.takeException(), isNull);

    // 2. Terpasang, belum izin -> ketuk minta izin -> menjadi Terhubung -> ketuk lagi buka /aktivitas/izin
    await t.pumpWidget(const SizedBox.shrink());
    final sumberTerpasang = _MockSumberAktivitas(
      tersediaNilai: true,
      status: StatusHealthConnect.tersedia,
      diizinkanNilai: false,
      hasilMintaIzin: true,
    );
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: sumberTerpasang,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/profil'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Langkah dan olahraga'));
    await t.pumpAndSettle();
    expect(find.text('Belum terhubung'), findsOneWidget);

    await t.tap(find.text('Langkah dan olahraga'));
    await t.pumpAndSettle();
    expect(sumberTerpasang.panggilMintaIzin, 1);
    expect(find.text('Terhubung'), findsOneWidget);

    await t.tap(find.text('Langkah dan olahraga'));
    await t.pumpAndSettle();
    expect(find.text('Akses Health Connect'), findsOneWidget);
    expect(find.text('Jumlah langkah'), findsOneWidget);
    expect(find.text('Sesi olahraga'), findsOneWidget);
    expect(find.text('Jarak'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Cara mencabut izin'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cara mencabut izin'), findsOneWidget);
    expect(find.textContaining('tidak dikirim ke server'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('galat dari SumberAktivitas tidak membuat Beranda, Riwayat, Rapor, atau Profil crash', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final sumberGalat = _MockSumberAktivitas(lemparGalat: true);
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => sekarang,
      sumberAktivitas: sumberGalat,
    );
    await getIt<AsupanRepository>().simpanKonsumsi(
      draf: const DrafProduk(nama: 'Roti', gulaG: 10, natriumMg: 100, lemakTotalG: 5),
      jumlahSajian: 1,
      waktuLokal: sekarang,
    );

    for (final rute in ['/beranda', '/riwayat', '/rapor', '/profil', '/aktivitas/izin']) {
      await t.pumpWidget(JeliLabelApp(awal: rute));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'rute $rute tidak boleh crash saat SumberAktivitas gagal');
      await t.pumpWidget(const SizedBox.shrink());
    }
  });
}
