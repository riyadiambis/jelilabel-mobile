import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
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

  testWidgets('navigasi 4 tab menampilkan Beranda, Riwayat, Rapor, Profil tanpa tab Tentang (320 px)', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Beranda')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Riwayat')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Rapor')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Profil')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Tentang')), findsNothing);

    await t.tap(find.descendant(of: nav, matching: find.text('Rapor')));
    await t.pumpAndSettle();
    expect(find.text('Rapor minggu ini'), findsOneWidget);

    await t.tap(find.descendant(of: nav, matching: find.text('Profil')));
    await t.pumpAndSettle();
    expect(find.text('Paket dan langganan'), findsOneWidget);
    expect(find.text('Data saya'), findsOneWidget);
    expect(find.text('Salin data'), findsOneWidget);
    expect(find.text('Hapus semua data'), findsOneWidget);
    expect(find.text('Tentang dan privasi'), findsOneWidget);

    // Menu yang belum ada fiturnya tidak dibuat
    expect(find.textContaining('keluarga'), findsNothing);
    expect(find.text('Produk saya'), findsNothing);
    expect(find.textContaining('Tantangan'), findsNothing);
    expect(find.text('Pengingat'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Profil menavigasi ke Paket dan langganan serta Tentang dan privasi dengan tombol kembali', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(JeliLabelApp(awal: '/profil'));
    await t.pumpAndSettle();

    await t.tap(find.text('Paket dan langganan'));
    await t.pumpAndSettle();
    expect(find.text('JeliLabel Plus'), findsOneWidget);
    await t.tap(find.byTooltip('Tutup'));
    await t.pumpAndSettle();
    expect(find.text('Profil'), findsWidgets);

    await t.tap(find.text('Tentang dan privasi'));
    await t.pumpAndSettle();
    expect(find.text('Acuan batas harian'), findsOneWidget);
    expect(find.byTooltip('Kembali'), findsOneWidget);

    await t.tap(find.byTooltip('Kembali'));
    await t.pumpAndSettle();
    expect(find.text('Paket dan langganan'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
  });
}
