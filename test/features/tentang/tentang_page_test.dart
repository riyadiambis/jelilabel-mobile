import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String? disalin;

  setUp(() async {
    disalin = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          disalin = args['text'] as String?;
        }
        return null;
      },
    );
    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await resetDependensi();
  });

  testWidgets('Tentang memuat disclaimer resmi PLAY-STORE 6.1 dan bagian Data saya', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(JeliLabelApp(awal: '/tentang'));
    await t.pumpAndSettle();

    expect(find.textContaining('Permenkes 30/2013'), findsOneWidget);
    expect(find.text('Baca selengkapnya'), findsOneWidget);
    await t.ensureVisible(find.text('Baca selengkapnya'));
    await t.pumpAndSettle();
    await t.tap(find.text('Baca selengkapnya'));
    await t.pumpAndSettle();
    expect(find.textContaining('bukan pengganti dokter'), findsOneWidget);
    await t.tap(find.byTooltip('Tutup'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Hapus semua data'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Hapus semua data'));
    await t.pumpAndSettle();
    expect(find.text('Data saya'), findsOneWidget);
    expect(find.text('Salin data'), findsOneWidget);
    expect(find.text('Hapus semua data'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Salin data membuka pratinjau JSON/CSV dan menyalin ke clipboard', (t) async {
    final repo = getIt<AsupanRepository>();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Susu Cokelat', gulaG: 12, natriumMg: 95),
      jumlahSajian: 1,
      waktuLokal: DateTime(2026, 11, 20, 9),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/tentang'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Salin data'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Salin data'));
    await t.pumpAndSettle();
    await t.tap(find.text('Salin data'));
    await t.pumpAndSettle();

    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);

    await t.tap(find.text('CSV'));
    await t.pumpAndSettle();
    expect(find.textContaining('Susu Cokelat'), findsOneWidget);

    await t.tap(find.text('JSON'));
    await t.pumpAndSettle();

    await t.tap(find.text('Salin'));
    await t.pumpAndSettle();

    expect(disalin, isNotNull);
    final decoded = jsonDecode(disalin!) as Map<String, dynamic>;
    expect((decoded['konsumsi'] as List).length, 1);
    expect(find.textContaining('Data disalin (1 catatan)'), findsOneWidget);
  });

  testWidgets('Hapus semua data butuh ketik HAPUS persis lalu reset DB dan ke /perkenalan', (t) async {
    final repo = getIt<AsupanRepository>();
    await repo.tandaiPerkenalanSelesai();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Teh', gulaG: 15),
      jumlahSajian: 1,
      waktuLokal: DateTime(2026, 11, 20, 9),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/tentang'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Hapus semua data'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Hapus semua data'));
    await t.pumpAndSettle();
    await t.tap(find.text('Hapus semua data'));
    await t.pumpAndSettle();

    expect(find.text('Hapus semua data?'), findsOneWidget);

    FilledButton tombolHapus() => t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hapus'));
    expect(tombolHapus().onPressed, isNull);

    await t.enterText(find.byType(TextField), 'hapus');
    await t.pump();
    expect(tombolHapus().onPressed, isNull);

    await t.enterText(find.byType(TextField), 'HAPUS');
    await t.pump();
    expect(tombolHapus().onPressed, isNotNull);

    await t.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await t.pumpAndSettle();

    expect(find.text('Hai, aku Nuri!'), findsOneWidget);
    expect(await repo.jumlahKonsumsi(), 0);
    expect(await repo.perkenalanSelesai(), isFalse);
  });
}
