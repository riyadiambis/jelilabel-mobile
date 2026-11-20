import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Ekspor data JSON/CSV, resetSemuaData, dan kuota mingguan', () {
    late BasisData basis;
    late AsupanRepository repo;
    late AsupanCubit cubit;

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      repo = AsupanRepository(basis.db);
      cubit = AsupanCubit(repo, jam: () => DateTime(2026, 11, 20, 10, 15));
    });

    tearDown(() async {
      await cubit.close();
      await basis.tutup();
    });

    test('eksporDataJson menghasilkan JSON valid dengan nilai null tetap null dan tanpa rahasia', () async {
      await repo.tandaiPerkenalanSelesai();
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh, "Manis"', gulaG: 15, natriumMg: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 8),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Keripik', gulaG: null, natriumMg: 300),
        jumlahSajian: 2,
        waktuLokal: DateTime(2026, 11, 20, 9),
      );
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Susu', gulaG: 12, natriumMg: 95),
        jumlahSajian: 0.5,
        waktuLokal: DateTime(2026, 11, 19, 14),
      );

      final jsonStr = await cubit.eksporDataJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['aplikasi'], 'JeliLabel');
      expect(decoded['versiSkema'], 1);
      expect((decoded['pengaturan'] as Map<String, dynamic>)['perkenalan_selesai'], '1');

      final produk = decoded['produk'] as List<dynamic>;
      final konsumsi = decoded['konsumsi'] as List<dynamic>;
      expect(produk, hasLength(3));
      expect(konsumsi, hasLength(3));

      final keripik = konsumsi.cast<Map<String, dynamic>>().firstWhere((k) => k['natrium_mg'] == 600.0);
      expect(keripik['gula_g'], isNull);

      expect(jsonStr.toLowerCase(), isNot(contains('password')));
      expect(jsonStr.toLowerCase(), isNot(contains('token')));
      expect(jsonStr, isNot(contains('jelilabel.db')));
    });

    test('eksporDataCsv memuat tabel produk, konsumsi, pengaturan dengan escaping RFC 4180', () async {
      await repo.tandaiPerkenalanSelesai();
      await repo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh, "Manis"', gulaG: 15),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 8),
      );

      final csv = await cubit.eksporDataCsv();
      final baris = csv.split('\n');
      expect(baris.first, startsWith('tabel,id,produk_id,nama,'));
      expect(csv, contains('produk,1,,"Teh, ""Manis""",'));
      expect(csv, contains('konsumsi,1,1,'));
      expect(csv, contains('pengaturan,'));
      expect(csv, contains('perkenalan_selesai,1'));
    });

    test('kuota mingguan tersimpan di pengaturan dan reset otomatis saat masuk Senin baru', () async {
      final kamis = DateTime(2026, 11, 19, 10);
      final minggu = DateTime(2026, 11, 22, 23, 50);
      final seninBaru = DateTime(2026, 11, 23, 0, 5);

      expect(awalMingguLokal(kamis), '2026-11-16');
      expect(awalMingguLokal(minggu), '2026-11-16');
      expect(awalMingguLokal(seninBaru), '2026-11-23');

      expect(await repo.bacaKuotaTerpakai(kamis), 0);
      expect(await repo.tambahKuotaTerpakai(kamis), 1);
      expect(await repo.tambahKuotaTerpakai(minggu), 2);
      expect(await repo.tambahKuotaBonusIklan(kamis), 1);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaMinggu), '2026-11-16');
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaTerpakai), '2');
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaBonusIklan), '1');

      final statusBaru = await repo.bacaStatusKuota(seninBaru);
      expect(statusBaru.terpakai, 0);
      expect(statusBaru.bonusIklan, 0);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaMinggu), '2026-11-23');
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaTerpakai), '0');
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaBonusIklan), '0');
    });

    test('resetSemuaData mengosongkan DB, kuota pengaturan, dan state tanpa muat ulang', () async {
      await repo.tandaiPerkenalanSelesai();
      await repo.tambahKuotaTerpakai(DateTime(2026, 11, 20, 10));
      await repo.tambahKuotaBonusIklan(DateTime(2026, 11, 20, 10));
      await cubit.simpan(const DrafProduk(nama: 'Teh', gulaG: 10), 1);
      expect(await cubit.jumlahCatatan(), 1);
      expect(await repo.jumlahProduk(), 1);

      await cubit.resetSemuaData();

      expect(cubit.state.daftar, isEmpty);
      expect(cubit.state.ringkasan, const RingkasanHari());
      expect(cubit.state.sisaKuota, AsupanState.kuotaGratisMingguan);
      expect(cubit.state.bonusIklanDipakai, 0);
      expect(cubit.state.halamanHabis, isTrue);
      expect(await repo.jumlahKonsumsi(), 0);
      expect(await repo.jumlahProduk(), 0);
      expect(await repo.perkenalanSelesai(), isFalse);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaMinggu), isNull);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaTerpakai), isNull);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaBonusIklan), isNull);
    });
  });
}
