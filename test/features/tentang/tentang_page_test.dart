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
  final List<(String method, Map<Object?, Object?>? args)> panggilanTautan = [];
  bool hasilBukaUrl = true;
  const channelTautan = MethodChannel('jelilabel/tautan');

  setUp(() async {
    disalin = null;
    panggilanTautan.clear();
    hasilBukaUrl = true;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channelTautan,
      (call) async {
        panggilanTautan.add((call.method, call.arguments as Map<Object?, Object?>?));
        return hasilBukaUrl;
      },
    );
    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channelTautan,
      null,
    );
    await resetDependensi();
  });

  testWidgets('Tentang memakai bahasa awam, tanpa G4 G1 L5, tanpa Hubungi Ofi Labs, dan tanpa Data saya', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(JeliLabelApp(awal: '/tentang'));
    await t.pumpAndSettle();

    expect(find.text('Tentang dan privasi'), findsOneWidget);
    expect(find.byTooltip('Kembali'), findsOneWidget);
    expect(find.textContaining('G4 G1 L5'), findsNothing);
    expect(find.textContaining('Permenkes 30/2013'), findsNothing);
    expect(find.textContaining('67 g'), findsOneWidget);
    expect(find.text('Hubungi Ofi Labs'), findsNothing);
    expect(find.text('Baca selengkapnya'), findsOneWidget);
    await t.ensureVisible(find.text('Baca selengkapnya'));
    await t.pumpAndSettle();
    await t.tap(find.text('Baca selengkapnya'));
    await t.pumpAndSettle();
    expect(find.textContaining('bukan pengganti dokter'), findsOneWidget);
    expect(find.textContaining('Kementerian Kesehatan RI'), findsOneWidget);
    expect(find.textContaining('G4 G1 L5'), findsNothing);
    expect(find.textContaining('Permenkes 30/2013'), findsNothing);
    await t.tap(find.byTooltip('Tutup'));
    await t.pumpAndSettle();

    expect(find.text('Data saya'), findsNothing);
    expect(find.text('Salin data'), findsNothing);
    expect(find.text('Hapus semua data'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Kebijakan privasi memanggil bukaUrl dan menampilkan snackbar bila gagal', (t) async {
    await t.pumpWidget(JeliLabelApp(awal: '/tentang'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.text('Kebijakan privasi'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('Kebijakan privasi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kebijakan privasi'));
    await t.pumpAndSettle();

    expect(panggilanTautan, hasLength(1));
    expect(panggilanTautan.single.$1, 'bukaUrl');
    expect(panggilanTautan.single.$2?['url'], 'https://riyadiambis.github.io/');
    expect(find.text('Tidak bisa membuka tautan.'), findsNothing);

    hasilBukaUrl = false;
    await t.tap(find.text('Kebijakan privasi'));
    await t.pumpAndSettle();
    expect(find.text('Tidak bisa membuka tautan.'), findsOneWidget);
  });

  testWidgets('Salin data di Profil membuka pratinjau JSON/CSV dan menyalin ke clipboard', (t) async {
    final repo = getIt<AsupanRepository>();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Susu Cokelat', gulaG: 12, natriumMg: 95),
      jumlahSajian: 1,
      waktuLokal: DateTime(2026, 11, 20, 9),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/profil'));
    await t.pumpAndSettle();

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

  testWidgets('Hapus semua data di Profil butuh ketik HAPUS persis lalu reset DB dan ke /perkenalan', (t) async {
    final repo = getIt<AsupanRepository>();
    await repo.tandaiPerkenalanSelesai();
    await repo.simpanKonsumsi(
      draf: const DrafProduk(nama: 'Teh', gulaG: 15),
      jumlahSajian: 1,
      waktuLokal: DateTime(2026, 11, 20, 9),
    );

    await t.pumpWidget(JeliLabelApp(awal: '/profil'));
    await t.pumpAndSettle();

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
