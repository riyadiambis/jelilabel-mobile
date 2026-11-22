import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/core/theme/warna.dart';
import 'package:jelilabel/core/widgets/komponen.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pindai/layanan_iklan.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Layar sempit 320 x 640: galat overflow membuat tes gagal (ISSUE-01: tidak boleh geser kanan-kiri).
void layarSempit(WidgetTester t) {
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

  testWidgets('perkenalan 3 halaman tampil di 320 px dan selesai menyimpan status', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp());
    await t.pumpAndSettle();
    expect(find.text('Hai, aku Nuri!'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    expect(find.textContaining('kamera', findRichText: true), findsNothing);

    await t.tap(find.text('Lanjut'));
    await t.pumpAndSettle();
    expect(find.text('Lihat jatah harianmu'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);

    await t.tap(find.text('Lanjut'));
    await t.pumpAndSettle();
    expect(find.text('Bukan saran medis'), findsOneWidget);
    expect(find.text('Lewati'), findsNothing);
    expect(find.text('Mulai pakai JeliLabel'), findsOneWidget);

    await t.tap(find.text('Mulai pakai JeliLabel'));
    await t.pumpAndSettle();
    expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
    expect(await getIt<AsupanRepository>().perkenalanSelesai(), isTrue);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('perkenalan Lewati di halaman pertama langsung ke Beranda dan menyimpan status selesai', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp());
    await t.pumpAndSettle();
    await t.tap(find.text('Lewati'));
    await t.pumpAndSettle();
    expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
    expect(await getIt<AsupanRepository>().perkenalanSelesai(), isTrue);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('alur pindai sampai simpan menambah total di Beranda (320 px)', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.text('Belum ada catatan hari ini'), findsOneWidget);

    await t.ensureVisible(find.text('Pindai Label Gizi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Pindai Label Gizi'));
    await t.pump();
    expect(find.text('Nuri sedang membaca labelnya...'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    expect(find.text('Cek hasil pindai'), findsOneWidget);
    expect(find.text('Waspada, karena gulanya'), findsOneWidget);
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();

    expect(find.text('Tercatat!'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('Tercatat!'), findsNothing);

    expect(find.text('Gula'), findsOneWidget);
    expect(find.text('12 g', findRichText: true), findsOneWidget);
    expect(find.text('Sisa 4 dari 5 minggu ini'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Beranda dengan catatan natrium null menampilkan jumlah tanpa data natrium', (t) async {
    layarSempit(t);
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Sirup', gulaG: 10, natriumMg: null),
      jumlahSajian: 1,
      waktuLokal: sekarang,
    );
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Keripik', gulaG: 2, natriumMg: 200),
      jumlahSajian: 1,
      waktuLokal: sekarang,
    );

    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();

    expect(find.text('12 g', findRichText: true), findsOneWidget);
    expect(find.text('200 mg', findRichText: true), findsOneWidget);
    expect(find.text('1 produk tanpa data natrium'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('isi manual: Simpan nonaktif saat gula dan natrium kosong, tampil Batal dan kotak garis putus', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Isi manual tanpa foto'));
    await t.pumpAndSettle();
    await t.tap(find.text('Isi manual tanpa foto'));
    await t.pumpAndSettle();

    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Buang'), findsNothing);
    expect(find.textContaining('Isi angka gula atau natrium.'), findsOneWidget);

    final simpanAwal = t.widget<TombolTebal>(find.widgetWithText(TombolTebal, 'Simpan'));
    expect(simpanAwal.onPressed, isNull);

    await t.enterText(find.byType(TextField).first, 'Keripik');
    await t.pump();
    expect(find.text('Buang'), findsOneWidget);
    final simpanTanpaAngka = t.widget<TombolTebal>(find.widgetWithText(TombolTebal, 'Simpan'));
    expect(simpanTanpaAngka.onPressed, isNull);

    await t.enterText(find.byType(TextField).at(1), '10');
    await t.pump();
    expect(find.textContaining('Isi angka gula atau natrium.'), findsNothing);
    final simpanDenganAngka = t.widget<TombolTebal>(find.widgetWithText(TombolTebal, 'Simpan'));
    expect(simpanDenganAngka.onPressed, isNotNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lewat batas, takaran terbuka, dan riwayat berisi tampil tanpa overflow (320 px)', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Isi manual tanpa foto'));
    await t.pumpAndSettle();
    await t.tap(find.text('Isi manual tanpa foto'));
    await t.pumpAndSettle();

    final isian = find.byType(TextField);
    await t.enterText(isian.at(0), 'Teh Kotak Manis Sekali Dengan Nama Panjang');
    await t.enterText(isian.at(1), '60');
    await t.enterText(isian.at(2), '2500');
    await t.ensureVisible(find.text('Takaran saji (opsional)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Takaran saji (opsional)'));
    await t.pumpAndSettle();
    expect(find.text('Sajian per kemasan'), findsOneWidget);
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    expect(find.text('Gula hari ini sudah lewat batas Kemenkes'), findsOneWidget);
    expect(find.text('Natrium hari ini sudah lewat batas Kemenkes'), findsOneWidget);

    await t.tap(find.text('Riwayat'));
    await t.pumpAndSettle();
    expect(find.text('Rata-rata 8,6 g per hari'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  for (final ukuran in const [Size(1280, 800), Size(800, 1280)]) {
    testWidgets('tablet ${ukuran.width.toInt()}x${ukuran.height.toInt()}: isi maks 600 dp, navigasi penuh, tanpa overflow',
        (t) async {
      t.view.physicalSize = ukuran;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pindai Label Gizi'));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(Scaffold).last).width, lessThanOrEqualTo(lebarMaksIsi));
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(NavigationBar)).width, ukuran.width);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final rute in ['/riwayat', '/tentang', '/langganan', '/kuota-habis', '/tidak-terbaca']) {
    testWidgets('$rute tampil tanpa overflow di 320 px', (t) async {
      layarSempit(t);
      await t.pumpWidget(JeliLabelApp(awal: rute));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('TombolPindai dan TombolTebal.bahaya sesuai spesifikasi ISSUE-04', (t) async {
    var ditekan = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TombolPindai(onPressed: () => ditekan++),
              const TombolPindai(onPressed: null),
              TombolTebal.bahaya(label: 'Buang', ikon: Icons.delete_outline_rounded, onPressed: () => ditekan++),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Pindai Label Gizi'), findsNWidgets(2));
    expect(find.text('Foto tabel gizi di kemasan'), findsNWidgets(2));
    expect(find.byIcon(Icons.photo_camera_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));

    final bahanAktif = t.widget<Material>(find.descendant(of: find.byType(TombolPindai).first, matching: find.byType(Material)));
    expect(bahanAktif.color, Warna.oranye);
    final bahanMati = t.widget<Material>(find.descendant(of: find.byType(TombolPindai).last, matching: find.byType(Material)));
    expect(bahanMati.color, Warna.garis);

    await t.tap(find.byType(TombolPindai).first);
    await t.tap(find.byType(TombolPindai).last);
    expect(ditekan, 1);

    final bahanBahaya = t.widget<Material>(find.descendant(of: find.byType(TombolTebal), matching: find.byType(Material)));
    expect(bahanBahaya.color, Warna.bahayaLatar);
    final bentukBahaya = bahanBahaya.shape! as RoundedRectangleBorder;
    expect(bentukBahaya.side.color, Warna.bahayaGaris);
    expect(bentukBahaya.side.width, 1.5);
    await t.tap(find.text('Buang'));
    expect(ditekan, 2);
  });

  testWidgets('CekHasilPage: porsi terpilih oranyeLembut dan tombol Buang bahaya tanpa overflow (320 px)', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Pindai Label Gizi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Pindai Label Gizi'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('1'));
    await t.pumpAndSettle();

    final porsiTerpilih = find.ancestor(of: find.text('1'), matching: find.byType(Material)).first;
    expect(t.widget<Material>(porsiTerpilih).color, Warna.oranyeLembut);
    final buangMaterial = find.ancestor(of: find.text('Buang'), matching: find.byType(Material)).first;
    expect(t.widget<Material>(buangMaterial).color, Warna.bahayaLatar);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('LanggananPage menampilkan segera hadir, rencana harga, dan tanpa klaim medis/pembelian', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/langganan'));
    await t.pumpAndSettle();
    expect(find.text('Segera hadir'), findsOneWidget);
    expect(find.text('rencana Rp15.000/bulan atau Rp59.900/6 bulan'), findsOneWidget);
    expect(
      find.text('5 pindai per minggu, tambah sampai 10 lewat video. Isi manual tanpa batas dan riwayat 7 hari.'),
      findsOneWidget,
    );
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Coba Plus'), findsNothing);
    expect(find.text('Pulihkan pembelian'), findsNothing);
    expect(find.textContaining('Pantau Diabetes'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('/kuota-habis menampilkan tombol tonton video dan memindai ulang saat berhasil (320 px)', (t) async {
    layarSempit(t);
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    for (var i = 0; i < AsupanState.kuotaGratisMingguan; i++) {
      await repo.tambahKuotaTerpakai(sekarang, maks: 15);
    }

    await t.pumpWidget(JeliLabelApp(awal: '/kuota-habis'));
    await t.pumpAndSettle();

    expect(find.text('Tonton video, +1 pindai'), findsOneWidget);
    expect(find.text('Bonus video: 0 dari 10 minggu ini'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.text('Tonton video, +1 pindai'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.pump(const Duration(milliseconds: 800));
    await t.pump();
    expect(find.text('Nuri sedang membaca labelnya...'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('Cek hasil pindai'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('/kuota-habis saat iklan gagal menampilkan SnackBar dan tetap di layar', (t) async {
    layarSempit(t);
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      layananIklan: const LayananIklanSimulasi(berhasil: false, jeda: Duration.zero),
    );
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    for (var i = 0; i < AsupanState.kuotaGratisMingguan; i++) {
      await repo.tambahKuotaTerpakai(sekarang, maks: 15);
    }

    await t.pumpWidget(JeliLabelApp(awal: '/kuota-habis'));
    await t.pumpAndSettle();

    await t.tap(find.text('Tonton video, +1 pindai'));
    await t.pumpAndSettle();

    expect(find.text('Nuri istirahat dulu'), findsOneWidget);
    expect(find.text('Video belum selesai. Kuota tidak bertambah.'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('/kuota-habis saat slot iklan 10 habis tidak menampilkan tombol tonton video', (t) async {
    layarSempit(t);
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    for (var i = 0; i < 15; i++) {
      await repo.tambahKuotaTerpakai(sekarang, maks: 15);
    }
    for (var i = 0; i < AsupanState.kuotaIklanMingguanMaks; i++) {
      await repo.tambahKuotaBonusIklan(sekarang, maks: AsupanState.kuotaIklanMingguanMaks);
    }

    await t.pumpWidget(JeliLabelApp(awal: '/kuota-habis'));
    await t.pumpAndSettle();

    expect(find.text('Tonton video, +1 pindai'), findsNothing);
    expect(find.text('Bonus video: 10 dari 10 minggu ini'), findsOneWidget);
    expect(find.textContaining('Batas 10 bonus iklan minggu ini sudah tercapai.'), findsOneWidget);
    expect(find.text('Isi manual'), findsOneWidget);
    expect(find.text('Tentang JeliLabel Plus'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tombol Pindai kembali oranye dan aktif setelah kembali dari layar galat lewat Isi manual -> Simpan',
      (t) async {
    layarSempit(t);
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    for (var i = 0; i < AsupanState.kuotaGratisMingguan; i++) {
      await repo.tambahKuotaTerpakai(sekarang, maks: 15);
    }

    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('Pindai Label Gizi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Pindai Label Gizi'));
    await t.pumpAndSettle();
    expect(find.text('Nuri istirahat dulu'), findsOneWidget);

    await t.tap(find.text('Isi manual'));
    await t.pumpAndSettle();
    final isian = find.byType(TextField);
    await t.enterText(isian.at(0), 'Air Mineral');
    await t.enterText(isian.at(1), '0');
    await t.pump();
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    final bahanPindai = t.widget<Material>(
      find.descendant(of: find.byType(TombolPindai), matching: find.byType(Material)),
    );
    expect(bahanPindai.color, Warna.oranye);
    expect(t.widget<TombolPindai>(find.byType(TombolPindai)).onPressed, isNotNull);

    await t.pumpWidget(const SizedBox.shrink());
  });
}
