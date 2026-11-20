import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pindai/layanan_iklan.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _IklanTerkendali implements LayananIklanKuota {
  int dipanggil = 0;
  Completer<bool>? completer;

  @override
  Future<bool> tampilkanVideoHadiah() {
    dipanggil++;
    final c = Completer<bool>();
    completer = c;
    return c.future;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  tearDown(() async {
    await resetDependensi();
  });

  testWidgets('/kuota-habis tidak memanggil iklan saat dibuka dan mengunci ketuk dua kali cepat', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final iklan = _IklanTerkendali();
    await siapkanDependensi(lokasiDb: inMemoryDatabasePath, layananIklan: iklan);
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    for (var i = 0; i < AsupanState.kuotaGratisMingguan; i++) {
      await repo.tambahKuotaTerpakai(sekarang, maks: AsupanState.plafonMingguan);
    }

    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: JeliLabelApp(awal: '/kuota-habis'),
      ),
    );
    await t.pumpAndSettle();

    expect(iklan.dipanggil, 0);
    expect(find.text('Tonton iklan (+1 pindai)'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.ensureVisible(find.text('Tonton iklan (+1 pindai)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tonton iklan (+1 pindai)'));
    await t.pump();
    await t.tap(find.text('Tonton iklan (+1 pindai)'));
    await t.pump();

    expect(iklan.dipanggil, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    iklan.completer!.complete(true);
    await t.pump();
    expect(find.text('Nuri sedang membaca labelnya...'), findsOneWidget);

    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('Cek hasil pindai'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Beranda menampilkan "dari 5" awal, "dari 15" setelah 10 bonus, dan tautan video saat habis', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.text('Sisa pindai minggu ini: 5 dari 5'), findsOneWidget);
    expect(find.text('Tambah lewat video'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());

    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
    final repo = getIt<AsupanRepository>();
    final sekarang = DateTime.now();
    for (var i = 0; i < 5; i++) {
      await repo.tambahKuotaTerpakai(sekarang);
    }
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.text('Sisa pindai minggu ini: 0 dari 5'), findsOneWidget);
    expect(find.text('Tambah lewat video'), findsOneWidget);

    await t.ensureVisible(find.text('Tambah lewat video'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tambah lewat video'));
    await t.pumpAndSettle();
    expect(find.text('Tonton iklan (+1 pindai)'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());

    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
    final repo2 = getIt<AsupanRepository>();
    for (var i = 0; i < 10; i++) {
      await repo2.tambahKuotaBonusIklan(sekarang);
    }
    await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
    await t.pumpAndSettle();
    expect(find.text('Sisa pindai minggu ini: 15 dari 15'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('/kuota-habis dan /langganan bebas overflow di 1280x800', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await siapkanDependensi(lokasiDb: inMemoryDatabasePath);
    await t.pumpWidget(JeliLabelApp(awal: '/kuota-habis'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());

    await t.pumpWidget(JeliLabelApp(awal: '/langganan'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
