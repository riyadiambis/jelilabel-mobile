import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/main.dart';

/// Layar sempit 320 x 640: galat overflow membuat tes gagal (ISSUE-01: tidak boleh geser kanan-kiri).
void layarSempit(WidgetTester t) {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('perkenalan tampil di 320 px', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp());
    expect(find.text('Hai, aku Nuri!'), findsOneWidget);
    await t.tap(find.text('Lanjut'));
    await t.pumpAndSettle();
    expect(find.text('Bukan saran medis'), findsOneWidget);
  });

  testWidgets('alur pindai sampai simpan menambah total di Beranda (320 px)', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
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
    expect(find.text('Sisa pindai minggu ini: 14 dari 15'), findsOneWidget);
  });

  testWidgets('isi manual: gula dan natrium kosong ditolak', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.ensureVisible(find.text('Isi manual'));
    await t.pumpAndSettle();
    await t.tap(find.text('Isi manual'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Keripik');
    await t.tap(find.text('Simpan'));
    await t.pump();
    expect(find.text('Isi gula atau natrium'), findsOneWidget);
  });

  testWidgets('lewat batas, takaran terbuka, dan riwayat berisi tampil tanpa overflow (320 px)', (t) async {
    layarSempit(t);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
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
  });

  for (final ukuran in const [Size(1280, 800), Size(800, 1280)]) {
    testWidgets('tablet ${ukuran.width.toInt()}x${ukuran.height.toInt()}: isi maks 600 dp, tanpa overflow', (t) async {
      t.view.physicalSize = ukuran;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.tap(find.text('Pindai Label Gizi'));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(Scaffold).last).width, lessThanOrEqualTo(lebarMaksIsi));
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(NavigationBar)).width, lessThanOrEqualTo(lebarMaksIsi));
      expect(t.takeException(), isNull);
    });
  }

  for (final rute in ['/riwayat', '/tentang', '/langganan', '/kuota-habis', '/tidak-terbaca']) {
    testWidgets('$rute tampil tanpa overflow di 320 px', (t) async {
      layarSempit(t);
      await t.pumpWidget(JeliLabelApp(awal: rute));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
