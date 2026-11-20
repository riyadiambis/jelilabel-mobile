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

  for (final rute in ['/riwayat', '/tentang', '/langganan', '/kuota-habis', '/tidak-terbaca']) {
    testWidgets('$rute tampil tanpa overflow di 320 px', (t) async {
      layarSempit(t);
      await t.pumpWidget(JeliLabelApp(awal: rute));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
