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

  testWidgets('ketuk baris Riwayat membuka lembar detail dengan takaran sendok gula, garam, dan minyak', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final repo = getIt<AsupanRepository>();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Minuman Cokelat', gulaG: 6.25, natriumMg: 1000, lemakTotalG: 13.4),
      jumlahSajian: 1,
      waktuLokal: DateTime.now(),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/riwayat'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Minuman Cokelat'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Minuman Cokelat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Minuman Cokelat'));
    await t.pumpAndSettle();

    expect(find.text('13,4 g'), findsOneWidget);
    expect(find.text('20% jatah harian'), findsOneWidget);
    expect(find.text('setara ½ sdm gula'), findsOneWidget);
    expect(find.text('setara ½ sdt garam'), findsOneWidget);
    expect(find.text('setara 1 sdm minyak'), findsOneWidget);
    expect(find.textContaining('Nilai dihitung saat dicatat'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('lembar detail menampilkan "-" untuk nilai null dan geser hapus tetap bekerja', (t) async {
    final repo = getIt<AsupanRepository>();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Sirup Manis', gulaG: 2, natriumMg: null, lemakTotalG: null),
      jumlahSajian: 1,
      waktuLokal: DateTime.now(),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/riwayat'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Sirup Manis'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Sirup Manis'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sirup Manis'));
    await t.pumpAndSettle();

    expect(find.text('setara < ½ sdm gula'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(2));
    expect(find.text('Tidak ada data'), findsNWidgets(2));
    expect(find.text('0 mg'), findsNothing);

    await t.tap(find.byTooltip('Tutup'));
    await t.pumpAndSettle();

    await t.drag(find.text('Sirup Manis'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('Urungkan'), findsOneWidget);
  });

  testWidgets('segmen Lemak di Riwayat menampilkan rata-rata dan batas 67 g (320 px)', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final repo = getIt<AsupanRepository>();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Gorengan', gulaG: 0, natriumMg: 100, lemakTotalG: 14),
      jumlahSajian: 1,
      waktuLokal: DateTime.now(),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/riwayat'));
    await t.pumpAndSettle();

    expect(find.text('Gula'), findsOneWidget);
    expect(find.text('Natrium'), findsOneWidget);
    expect(find.text('Lemak'), findsOneWidget);

    await t.tap(find.text('Lemak'));
    await t.pumpAndSettle();

    expect(find.text('Batas 67 g'), findsOneWidget);
    expect(find.text('Rata-rata 2 g per hari'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
