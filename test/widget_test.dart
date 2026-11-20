import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/core/theme/warna.dart';
import 'package:jelilabel/core/widgets/komponen.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
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

  testWidgets('perkenalan 3 halaman tampil di 320 px dan Lewati menyimpan status selesai', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp());
    await t.pumpAndSettle();
    expect(find.text('Hai, aku Nuri!'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.textContaining('kamera', findRichText: true), findsNothing);

    await t.tap(find.text('Lanjut'));
    await t.pumpAndSettle();
    expect(find.text('Catat, lihat jatah harian'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);

    await t.tap(find.text('Lanjut'));
    await t.pumpAndSettle();
    expect(find.text('Bukan saran medis'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);

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

    await t.tap(find.text('Pindai Label Gizi'));
    await t.pump();
    expect(find.text('Nuri sedang membaca labelnya...'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    expect(find.text('Cek hasil pindai'), findsOneWidget);
    expect(find.text('Waspada, karena gulanya'), findsOneWidget);
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();

    expect(find.text('Gula'), findsOneWidget);
    expect(find.text('12 g', findRichText: true), findsOneWidget);
    expect(find.text('Sisa pindai minggu ini: 9 dari 10'), findsOneWidget);

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

  testWidgets('isi manual: gula dan natrium kosong ditolak', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Isi manual'));
    await t.pumpAndSettle();
    await t.tap(find.text('Isi manual'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Keripik');
    await t.tap(find.text('Simpan'));
    await t.pump();
    expect(find.text('Isi gula atau natrium'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lewat batas, takaran terbuka, dan riwayat berisi tampil tanpa overflow (320 px)', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Isi manual'));
    await t.pumpAndSettle();
    await t.tap(find.text('Isi manual'));
    await t.pumpAndSettle();

    final isian = find.byType(TextField);
    await t.enterText(isian.at(0), 'Teh Kotak Manis Sekali Dengan Nama Panjang');
    await t.enterText(isian.at(1), '60');
    await t.enterText(isian.at(2), '2500');
    await t.scrollUntilVisible(
      find.text('Takaran saji (opsional)'),
      100,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    await t.ensureVisible(find.text('Takaran saji (opsional)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Takaran saji (opsional)'));
    await t.pumpAndSettle();
    expect(find.text('Sajian per kemasan'), findsOneWidget);
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();

    expect(find.text('Gula hari ini sudah lewat batas Kemenkes'), findsOneWidget);
    expect(find.text('Natrium hari ini sudah lewat batas Kemenkes'), findsOneWidget);

    await t.tap(find.text('Riwayat'));
    await t.pumpAndSettle();
    expect(find.text('1 hari lewat batas'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  for (final ukuran in const [Size(1280, 800), Size(800, 1280)]) {
    testWidgets('tablet ${ukuran.width.toInt()}x${ukuran.height.toInt()}: isi maks 600 dp, tanpa overflow', (t) async {
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
      expect(t.getSize(find.byType(NavigationBar)).width, lessThanOrEqualTo(lebarMaksIsi));
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
    await t.tap(find.text('Pindai Label Gizi'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('1 sajian'),
      100,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    await t.pumpAndSettle();

    final porsiTerpilih = find.ancestor(of: find.text('1 sajian'), matching: find.byType(Material)).first;
    expect(t.widget<Material>(porsiTerpilih).color, Warna.oranyeLembut);
    final buangMaterial = find.ancestor(of: find.text('Buang'), matching: find.byType(Material)).first;
    expect(t.widget<Material>(buangMaterial).color, Warna.bahayaLatar);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('LanggananPage menampilkan kuota gratis 10 pindai per minggu', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/langganan'));
    await t.pumpAndSettle();
    expect(find.text('10 pindai per minggu · isi manual tanpa batas'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
