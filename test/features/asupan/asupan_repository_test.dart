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

    test('pulihkanKonsumsi mempertahankan id dan urutan halamanRiwayat seperti semula', () async {
      final waktu = DateTime(2026, 11, 20, 9, 15);
      final id1 = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Item 1', gulaG: 5),
        jumlahSajian: 1,
        waktuLokal: waktu,
      );
      final id2 = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Item 2', gulaG: 10),
        jumlahSajian: 1,
        waktuLokal: waktu,
      );
      final id3 = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Item 3', gulaG: 15),
        jumlahSajian: 1,
        waktuLokal: waktu,
      );

      final urutanAwal = await repo.halamanRiwayat();
      expect(urutanAwal.map((e) => e.id).toList(), [id3, id2, id1]);

      final dihapus = await repo.hapusKonsumsi(id2);
      expect(dihapus, isNotNull);
      expect(dihapus!.id, id2);
      expect((await repo.halamanRiwayat()).map((e) => e.id).toList(), [id3, id1]);

      final idPulih = await repo.pulihkanKonsumsi(dihapus);
      expect(idPulih, id2);

      final urutanSesudah = await repo.halamanRiwayat();
      expect(urutanSesudah, urutanAwal);
      expect(urutanSesudah.map((e) => e.id).toList(), [id3, id2, id1]);
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

    test('pengaturan peringatan gula/natrium/lemak dan validasi nama zat', () async {
      final hari1 = DateTime(2026, 11, 20, 10);
      final hari2 = DateTime(2026, 11, 21, 8);

      expect(await repo.bolehPeringatan('gula', hari1), isTrue);
      await repo.tandaiPeringatan('gula', hari1);
      expect(await repo.bolehPeringatan('gula', hari1), isFalse);
      expect(await repo.bolehPeringatan('natrium', hari1), isTrue);
      expect(await repo.bolehPeringatan('lemak', hari1), isTrue);
      await repo.tandaiPeringatan('lemak', hari1);
      expect(await repo.bolehPeringatan('lemak', hari1), isFalse);
      expect(await repo.bolehPeringatan('gula', hari2), isTrue);
      expect(await repo.bolehPeringatan('lemak', hari2), isTrue);

      await expectLater(repo.bolehPeringatan('protein', hari1), throwsArgumentError);
    });

    test('lemakTotalG disalin sesuai porsi dan NULL dihitung 0 untuk total harian/rentang', () async {
      final hari = DateTime(2026, 11, 20, 12);
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Gorengan', gulaG: 1, natriumMg: 120, lemakTotalG: 7),
        jumlahSajian: 2,
        waktuLokal: hari,
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Sirup', gulaG: 10, lemakTotalG: null),
        jumlahSajian: 1,
        waktuLokal: hari,
      );

      final ringkasan = await repo.ringkasanHari(hari);
      expect(ringkasan.totalLemak, 14);
      expect(ringkasan.jumlahTanpaLemak, 1);

      final rentang = await repo.ringkasanRentang(hari, hari);
      expect(rentang['2026-11-20']?.lemak, 14);

      final riwayat = await repo.halamanRiwayat();
      expect(riwayat.first.lemakTotalG, isNull);
      expect(riwayat.last.lemakTotalG, 14);
    });

    test('ringkasanMinggu menghitung hari di bawah batas, hari kosong, dan rata-rata hari tercatat', () async {
      // Senin 16 Nov 2026 s.d. Minggu 22 Nov 2026
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 20, natriumMg: 400, lemakTotalG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 16, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Sirup', gulaG: 60, natriumMg: 200, lemakTotalG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 17, 10),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Susu', gulaG: 10, natriumMg: 600, lemakTotalG: 30),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 19, 12),
      );

      final r = await repo.ringkasanMinggu(DateTime(2026, 11, 19));
      expect(r.awalMinggu, DateTime(2026, 11, 16));
      expect(r.akhirMinggu, DateTime(2026, 11, 22));
      expect(r.jumlahCatatan, 3);
      expect(r.hariAdaCatatan, 3);
      expect(r.hariKosong, 4);
      // Senin (20 <= 50) & Kamis (10 <= 50) di bawah batas; Selasa (60 > 50) lewat batas; 4 hari kosong tidak dihitung.
      expect(r.hariGulaDiBawahBatas, 2);
      expect(r.rataGula, 30);
      expect(r.rataNatrium, 400);
      expect(r.rataLemak, 20);
    });

    test('penyumbangGulaMinggu mengurutkan 3 produk teratas menurut total gula beserta persen dan kali', () async {
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis', gulaG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 16, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis', gulaG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 17, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Roti Cokelat', gulaG: 30),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 18, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Kopi Susu', gulaG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 19, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Biskuit', gulaG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 9),
      );

      final daftar = await repo.penyumbangGulaMinggu(DateTime(2026, 11, 18));
      expect(daftar, hasLength(3));
      expect(daftar[0].nama, 'Teh Manis');
      expect(daftar[0].totalGula, 40);
      expect(daftar[0].persen, closeTo(0.4, 0.001));
      expect(daftar[0].jumlahKali, 2);
      expect(daftar[1].nama, 'Roti Cokelat');
      expect(daftar[1].persen, closeTo(0.3, 0.001));
      expect(daftar[2].nama, 'Kopi Susu');
      expect(daftar[2].persen, closeTo(0.2, 0.001));
    });

    test('ubahPorsi menghitung ulang nilai gizi berdasarkan nilai produk dan menjaga null tetap null', () async {
      final id = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 12, natriumMg: 80, lemakTotalG: null),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 9),
      );

      final terbaru = await repo.ubahPorsi(id, 2.5);
      expect(terbaru, isNotNull);
      expect(terbaru!.jumlahSajian, 2.5);
      expect(terbaru.gulaG, 30);
      expect(terbaru.natriumMg, 200);
      expect(terbaru.lemakTotalG, isNull);

      final dariDb = (await repo.halamanRiwayat()).single;
      expect(dariDb.jumlahSajian, 2.5);
      expect(dariDb.gulaG, 30);
      expect(dariDb.natriumMg, 200);
      expect(dariDb.lemakTotalG, isNull);
    });

    test('catatUlang membuat baris baru pada tanggal hari ini dengan produk dan porsi sama', () async {
      final idLama = await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Susu', gulaG: 10, natriumMg: 90, lemakTotalG: 5),
        jumlahSajian: 2,
        waktuLokal: DateTime(2026, 11, 15, 8),
      );

      final idBaru = await repo.catatUlang(idLama, waktuLokal: DateTime(2026, 11, 20, 14, 30));
      expect(idBaru, isNot(idLama));

      final semua = await repo.halamanRiwayat();
      expect(semua, hasLength(2));
      expect(semua.first.id, idBaru);
      expect(semua.first.tanggal, '2026-11-20');
      expect(semua.first.jumlahSajian, 2);
      expect(semua.first.gulaG, 20);
      expect(semua.first.natriumMg, 180);
      expect(semua.first.lemakTotalG, 10);
      expect(semua.last.tanggal, '2026-11-15');
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
