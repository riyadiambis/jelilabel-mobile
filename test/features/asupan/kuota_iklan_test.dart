import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pindai/layanan_iklan.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _LayananIklanFake implements LayananIklanKuota {
  _LayananIklanFake({this.hasil = true});
  bool hasil;
  int dipanggil = 0;

  @override
  Future<bool> tampilkanVideoHadiah() async {
    dipanggil++;
    return hasil;
  }
}

class _RepoGagalBonus extends AsupanRepository {
  _RepoGagalBonus(super.db);

  @override
  Future<int> tambahKuotaBonusIklan(DateTime hari, {int maks = 10}) async {
    throw StateError('simulasi gagal tulis');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Kuota 5 + Bonus Iklan Rewarded (ISSUE-08)', () {
    late BasisData basis;
    late AsupanRepository repo;
    late DateTime sekarang;

    setUp(() async {
      sekarang = DateTime(2026, 11, 19, 10, 0);
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      repo = AsupanRepository(basis.db);
    });

    tearDown(() async {
      await basis.tutup();
    });

    test('1. Awal tanpa data: sisaKuota 5, bonusIklanDipakai 0, plafonKuota 5', () async {
      final cubit = AsupanCubit(repo, jam: () => sekarang);
      await cubit.muat();
      expect(cubit.state.sisaKuota, 5);
      expect(cubit.state.bonusIklanDipakai, 0);
      expect(cubit.state.sisaSlotIklan, 10);
      expect(cubit.state.plafonKuota, 5);
      await cubit.close();
    });

    test('2. Pindai berhasil 5 kali membuat sisaKuota 0 dan kuota_terpakai = "5"', () async {
      final cubit = AsupanCubit(repo, jam: () => sekarang);
      await cubit.muat();
      var berhasil = 0;
      for (var i = 0; i < 6; i++) {
        if (cubit.pindaiSimulasi() != null) berhasil++;
      }
      expect(berhasil, 5);
      expect(cubit.state.sisaKuota, 0);
      await cubit.close();

      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaTerpakai), '5');
    });

    test('3-4. klaimBonusIklan hingga 10 kali; klaim ke-11 false tanpa memanggil layanan iklan', () async {
      final fake = _LayananIklanFake(hasil: true);
      final cubit = AsupanCubit(repo, jam: () => sekarang, iklan: fake);
      await cubit.muat();
      for (var i = 0; i < 6; i++) {
        cubit.pindaiSimulasi();
      }
      expect(cubit.state.sisaKuota, 0);

      expect(await cubit.klaimBonusIklan(), isTrue);
      expect(cubit.state.sisaKuota, 1);
      expect(cubit.state.bonusIklanDipakai, 1);
      expect(cubit.state.plafonKuota, 6);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaBonusIklan), '1');

      for (var i = 2; i <= 10; i++) {
        expect(await cubit.klaimBonusIklan(), isTrue);
        expect(cubit.state.bonusIklanDipakai, i);
        expect(cubit.state.sisaKuota, i);
      }
      expect(cubit.state.sisaSlotIklan, 0);
      expect(cubit.state.plafonKuota, 15);
      expect(fake.dipanggil, 10);

      expect(await cubit.klaimBonusIklan(), isFalse);
      expect(fake.dipanggil, 10);
      expect(cubit.state.bonusIklanDipakai, 10);
      expect(cubit.state.sisaKuota, 10);
      await cubit.close();
    });

    test('5. Fake false tidak mengubah kuota maupun bonusIklanDipakai', () async {
      final fake = _LayananIklanFake(hasil: false);
      final cubit = AsupanCubit(repo, jam: () => sekarang, iklan: fake);
      await cubit.muat();

      expect(await cubit.klaimBonusIklan(), isFalse);
      expect(fake.dipanggil, 1);
      expect(cubit.state.sisaKuota, 5);
      expect(cubit.state.bonusIklanDipakai, 0);
      await cubit.close();
    });

    test('6. Gagal menulis repository saat klaim mengembalikan false dan tidak menambah sisaKuota', () async {
      final fake = _LayananIklanFake(hasil: true);
      final repoGagal = _RepoGagalBonus(basis.db);
      final cubit = AsupanCubit(repoGagal, jam: () => sekarang, iklan: fake);
      await cubit.muat();

      expect(await cubit.klaimBonusIklan(), isFalse);
      expect(cubit.state.sisaKuota, 5);
      expect(cubit.state.bonusIklanDipakai, 0);
      expect(cubit.state.galat, isNotNull);
      await cubit.close();
    });

    test('7-8. Persistensi berkas DB saat buka ulang dan reset Senin menjaga catatan lama', () async {
      final dir = await Directory.systemTemp.createTemp('jelilabel_kuota_iklan_');
      final path = join(dir.path, 'kuota.db');
      try {
        final b1 = await BasisData.buka(lokasiDb: path);
        final r1 = AsupanRepository(b1.db);
        final c1 = AsupanCubit(r1, jam: () => sekarang, iklan: _LayananIklanFake(hasil: true));
        await c1.muat();
        await c1.simpan(const DrafProduk(nama: 'Teh Manis', gulaG: 10), 1);
        await c1.klaimBonusIklan();
        expect(c1.state.bonusIklanDipakai, 1);
        await c1.close();
        await b1.tutup();

        final b2 = await BasisData.buka(lokasiDb: path);
        final r2 = AsupanRepository(b2.db);
        final c2 = AsupanCubit(r2, jam: () => sekarang);
        await c2.muat();
        expect(c2.state.bonusIklanDipakai, 1);
        expect(c2.state.sisaKuota, 6);
        expect(await r2.jumlahKonsumsi(), 1);

        sekarang = DateTime(2026, 11, 23, 0, 1);
        await c2.segarkan();
        expect(c2.state.bonusIklanDipakai, 0);
        expect(c2.state.sisaKuota, 5);
        expect(await r2.bacaKuotaTerpakai(sekarang), 0);
        expect(await r2.bacaKuotaBonusIklan(sekarang), 0);
        expect(await r2.jumlahKonsumsi(), 1);
        await c2.close();
        await b2.tutup();
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('9. resetSemuaData menghapus kuota_bonus_iklan dan mengembalikan kuota ke 5 / bonus 0', () async {
      final cubit = AsupanCubit(repo, jam: () => sekarang, iklan: _LayananIklanFake(hasil: true));
      await cubit.muat();
      await cubit.klaimBonusIklan();
      expect(cubit.state.bonusIklanDipakai, 1);

      await cubit.resetSemuaData();
      expect(cubit.state.sisaKuota, 5);
      expect(cubit.state.bonusIklanDipakai, 0);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaBonusIklan), isNull);
      await cubit.close();
    });

    test('10. sisaKuota tidak pernah melebihi 15 atau negatif', () async {
      final cubit = AsupanCubit(
        repo,
        jam: () => sekarang,
        sisaKuotaAwal: 15,
        iklan: _LayananIklanFake(hasil: true),
      );
      await cubit.muat();
      expect(await cubit.klaimBonusIklan(), isTrue);
      expect(cubit.state.sisaKuota, lessThanOrEqualTo(AsupanState.plafonMingguan));

      final habis = AsupanCubit(repo, jam: () => sekarang, sisaKuotaAwal: 0);
      expect(habis.pindaiSimulasi(), isNull);
      expect(habis.state.sisaKuota, 0);
      await cubit.close();
      await habis.close();
    });

    test('data lama ISSUE-07 tanpa kunci bonus mengembalikan 0 tanpa menulis', () async {
      await repo.tulisPengaturan(AsupanRepository.kunciKuotaMinggu, awalMingguLokal(sekarang));
      await repo.tulisPengaturan(AsupanRepository.kunciKuotaTerpakai, '3');

      expect(await repo.bacaKuotaBonusIklan(sekarang), 0);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaBonusIklan), isNull);

      await repo.tulisPengaturan(AsupanRepository.kunciKuotaBonusIklan, '-2');
      expect(await repo.bacaKuotaBonusIklan(sekarang), 0);
      await repo.tulisPengaturan(AsupanRepository.kunciKuotaBonusIklan, 'bukan_angka');
      expect(await repo.bacaKuotaBonusIklan(sekarang), 0);
    });

    test('klaimBonusIklan saat state.memuat true mengembalikan false tanpa memanggil layanan', () async {
      final fake = _LayananIklanFake(hasil: true);
      final cubit = AsupanCubit(repo, jam: () => sekarang, iklan: fake);
      final masaMuat = cubit.muat();
      expect(cubit.state.memuat, isTrue);
      expect(await cubit.klaimBonusIklan(), isFalse);
      expect(fake.dipanggil, 0);
      await masaMuat;
      await cubit.close();
    });
  });
}
