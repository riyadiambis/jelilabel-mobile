import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AsupanRepository', () {
    late BasisData basis;
    late AsupanRepository repo;

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      repo = AsupanRepository(basis.db);
    });

    tearDown(() async {
      await basis.tutup();
    });

    test('tanggalLokal memakai waktu lokal termasuk pukul 00:30', () {
      expect(tanggalLokal(DateTime(2026, 11, 20, 0, 30)), '2026-11-20');
      expect(tanggalLokal(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });

    test('simpanKonsumsi menolak jumlahSajian <= 0 sebelum menyentuh basis data', () async {
      await expectLater(
        repo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Teh', gulaG: 10),
          jumlahSajian: 0,
          waktuLokal: DateTime(2026, 11, 20, 10),
        ),
        throwsArgumentError,
      );
    });

    test('snapshot konsumsi tetap saat produk di-update dan nilai null tetap null', () async {
      final waktu = DateTime(2026, 11, 20, 0, 30);
      final id = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Susu', gulaG: 12, natriumMg: null, takaranSatuan: 'tidak_sah'),
        jumlahSajian: 0.5,
        waktuLokal: waktu,
      );

      final riwayatAwal = await repo.halamanRiwayat();
      expect(riwayatAwal.single.id, id);
      expect(riwayatAwal.single.gulaG, 6);
      expect(riwayatAwal.single.natriumMg, isNull);
      expect(riwayatAwal.single.tanggal, '2026-11-20');

      await basis.db.update('produk', {'gula_g': 99}, where: 'id = ?', whereArgs: [riwayatAwal.single.produkId]);
      final riwayatSesudah = await repo.halamanRiwayat();
      expect(riwayatSesudah.single.gulaG, 6);

      final ringkasan = await repo.ringkasanHari(waktu);
      expect(ringkasan.totalGula, 6);
      expect(ringkasan.totalNatrium, 0);
      expect(ringkasan.jumlahCatatan, 1);
      expect(ringkasan.jumlahTanpaGula, 0);
      expect(ringkasan.jumlahTanpaNatrium, 1);
    });

    test('pagination keyset 55 baris dan 500 baris tanpa dobel atau terlewat', () async {
      final dasar = DateTime(2026, 11, 20, 12);
      for (var i = 0; i < 55; i++) {
        await repo.simpanKonsumsi(
          draf: DrafProduk(nama: 'Produk $i', gulaG: i.toDouble()),
          jumlahSajian: 1,
          waktuLokal: dasar.subtract(Duration(days: i % 10)),
        );
      }

      final semua = <int>[];
      ({String tanggal, int id})? kursor;
      final halaman1 = await repo.halamanRiwayat(batas: 20);
      expect(halaman1, hasLength(20));
      semua.addAll(halaman1.map((e) => e.id));
      kursor = (tanggal: halaman1.last.tanggal, id: halaman1.last.id);

      final halaman2 = await repo.halamanRiwayat(batas: 20, sebelum: kursor);
      expect(halaman2, hasLength(20));
      semua.addAll(halaman2.map((e) => e.id));
      kursor = (tanggal: halaman2.last.tanggal, id: halaman2.last.id);

      final halaman3 = await repo.halamanRiwayat(batas: 20, sebelum: kursor);
      expect(halaman3, hasLength(15));
      semua.addAll(halaman3.map((e) => e.id));

      expect(semua.toSet(), hasLength(55));
    });

    test('pagination 500 baris terambil bertahap per halaman', () async {
      final dasar = DateTime(2026, 11, 20, 8);
      for (var i = 0; i < 500; i++) {
        await repo.simpanKonsumsi(
          draf: DrafProduk(nama: 'Item $i', gulaG: 5),
          jumlahSajian: 1,
          waktuLokal: dasar.subtract(Duration(minutes: i)),
        );
      }

      final terkumpul = <BarisRiwayat>[];
      ({String tanggal, int id})? kursor;
      while (true) {
        final hal = await repo.halamanRiwayat(batas: 30, sebelum: kursor);
        if (hal.isEmpty) break;
        terkumpul.addAll(hal);
        if (hal.length < 30) break;
        kursor = (tanggal: hal.last.tanggal, id: hal.last.id);
      }
      expect(terkumpul, hasLength(500));
      expect(terkumpul.map((e) => e.id).toSet(), hasLength(500));
    });

    test('hapusKonsumsi tidak menghapus produk dan pulihkanKonsumsi mengembalikan baris', () async {
      final waktu = DateTime(2026, 11, 20, 9, 15);
      final id = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis', gulaG: 20, natriumMg: 15),
        jumlahSajian: 1.5,
        waktuLokal: waktu,
      );

      final dihapus = await repo.hapusKonsumsi(id);
      expect(dihapus, isNotNull);
      expect(dihapus!.gulaG, 30);
      expect(await repo.halamanRiwayat(), isEmpty);

      final jumlahProduk = await basis.db.rawQuery('SELECT COUNT(*) FROM produk');
      expect(jumlahProduk.single.values.single, 1);

      await repo.pulihkanKonsumsi(dihapus);
      final pulih = await repo.halamanRiwayat();
      expect(pulih, hasLength(1));
      expect(pulih.single.produkId, dihapus.produkId);
      expect(pulih.single.gulaG, 30);
      expect(pulih.single.tanggal, '2026-11-20');
    });

    test('hapusSemuaData mengosongkan konsumsi, produk, dan pengaturan', () async {
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 10),
      );
      await repo.tandaiPerkenalanSelesai();
      await repo.hapusSemuaData();

      expect(await repo.halamanRiwayat(), isEmpty);
      expect(await repo.perkenalanSelesai(), isFalse);
      final produk = await basis.db.query('produk');
      expect(produk, isEmpty);
    });

    test('pengaturan peringatan gula/natrium dan validasi nama zat', () async {
      final hari1 = DateTime(2026, 11, 20, 10);
      final hari2 = DateTime(2026, 11, 21, 8);

      expect(await repo.bolehPeringatan('gula', hari1), isTrue);
      await repo.tandaiPeringatan('gula', hari1);
      expect(await repo.bolehPeringatan('gula', hari1), isFalse);
      expect(await repo.bolehPeringatan('natrium', hari1), isTrue);
      expect(await repo.bolehPeringatan('gula', hari2), isTrue);

      await expectLater(repo.bolehPeringatan('lemak', hari1), throwsArgumentError);
    });
  });

  test('pengaturan perkenalanSelesai bertahan setelah berkas DB dibuka ulang', () async {
    final dir = await Directory.systemTemp.createTemp('jelilabel_repo_test_');
    final path = join(dir.path, 'repo.db');
    try {
      final b1 = await BasisData.buka(lokasiDb: path);
      final r1 = AsupanRepository(b1.db);
      expect(await r1.perkenalanSelesai(), isFalse);
      await r1.tandaiPerkenalanSelesai();
      await b1.tutup();

      final b2 = await BasisData.buka(lokasiDb: path);
      final r2 = AsupanRepository(b2.db);
      expect(await r2.perkenalanSelesai(), isTrue);
      await b2.tutup();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
