import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pindai/layanan_iklan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late BasisData basis;
  late AsupanRepository repo;
  late DateTime sekarang;

  setUp(() async {
    sekarang = DateTime(2026, 11, 19, 10, 15);
    basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
    repo = AsupanRepository(basis.db);
  });

  tearDown(() async {
    await basis.tutup();
  });

  AsupanCubit buat({int? sisaKuotaAwal, LayananIklanKuota? layananIklan}) =>
      AsupanCubit(repo, jam: () => sekarang, sisaKuotaAwal: sisaKuotaAwal, layananIklan: layananIklan);

  test('simpan menambah total hari ini sesuai porsi', () async {
    final c = buat();
    await c.muat();
    final draf = c.pindaiSimulasi()!;
    await c.simpan(draf, 2);
    expect(c.state.ringkasan.totalGula, 24);
    expect(c.state.ringkasan.totalNatrium, 190);
    expect(c.state.totalGula(DateTime(2026, 11, 18)), 0);
    await c.close();
  });

  test('kuota berkurang dari 5 hanya saat label terbaca dan bertahan saat muat ulang', () async {
    final c = buat();
    await c.muat();
    expect(c.state.sisaKuota, 5);
    for (var i = 0; i < 4; i++) {
      expect(c.pindaiSimulasi(), isNotNull);
    }
    expect(c.state.sisaKuota, 1);
    expect(c.pindaiSimulasi(), isNull, reason: 'percobaan ke-5 disimulasikan gagal');
    expect(c.state.sisaKuota, 1);
    await c.close();

    // Cubit baru di minggu yang sama -> sisa kuota tetap 1
    final c2 = buat();
    await c2.muat();
    expect(c2.state.sisaKuota, 1);

    // Masuk Senin minggu baru -> kuota reset otomatis ke 5
    sekarang = DateTime(2026, 11, 23, 7, 0);
    await c2.segarkan();
    expect(c2.state.sisaKuota, 5);
    expect(c2.state.bonusIklanDipakai, 0);
    await c2.close();
  });

  test('klaimBonusIklan menambah +1 kuota hingga batas 10 iklan/minggu dan ditolak bila gagal', () async {
    final gagal = buat(layananIklan: const LayananIklanSimulasi(berhasil: false));
    await gagal.muat();
    expect(await gagal.klaimBonusIklan(), isFalse);
    expect(gagal.state.sisaKuota, 5);
    expect(gagal.state.bonusIklanDipakai, 0);
    await gagal.close();

    final c = buat(layananIklan: const LayananIklanSimulasi(berhasil: true));
    await c.muat();
    for (var i = 1; i <= 10; i++) {
      expect(await c.klaimBonusIklan(), isTrue);
      expect(c.state.bonusIklanDipakai, i);
      expect(c.state.sisaSlotIklan, 10 - i);
      expect(c.state.sisaKuota, 5 + i);
    }
    // Klaim ke-11 melebihi batas +10 iklan/minggu ditolak
    expect(await c.klaimBonusIklan(), isFalse);
    expect(c.state.bonusIklanDipakai, 10);
    expect(c.state.sisaKuota, 15);
    await c.close();

    // Persistensi lintas buka ulang dan reset saat masuk Senin baru
    final c2 = buat();
    await c2.muat();
    expect(c2.state.bonusIklanDipakai, 10);
    expect(c2.state.sisaKuota, 15);

    sekarang = DateTime(2026, 11, 23, 8, 0);
    await c2.segarkan();
    expect(c2.state.bonusIklanDipakai, 0);
    expect(c2.state.sisaKuota, 5);
    await c2.close();
  });

  test('nilai null tidak dijumlahkan sebagai 0 dan tercatat tanpa data', () async {
    final c = buat();
    await c.simpan(const DrafProduk(nama: 'Keripik', natriumMg: 300), 1);
    expect(c.state.daftar.single.gulaG, isNull);
    expect(c.state.ringkasan.totalNatrium, 300);
    expect(c.state.ringkasan.jumlahTanpaGula, 1);
    expect(c.state.ringkasan.jumlahTanpaNatrium, 0);
    await c.close();
  });

  test('hapus lalu kembalikan', () async {
    final c = buat();
    await c.simpan(const DrafProduk(nama: 'Teh', gulaG: 20), 1);
    final k = c.state.daftar.single;
    await c.hapus(k);
    expect(c.state.daftar, isEmpty);
    expect(c.state.ringkasan.totalGula, 0);
    await c.kembalikan(k);
    expect(c.state.daftar, hasLength(1));
    expect(c.state.ringkasan.totalGula, 20);
    await c.close();
  });

  test('hapus satu dari dua catatan yang sama persis', () async {
    final c = buat();
    const d = DrafProduk(nama: 'Teh', gulaG: 20);
    await c.simpan(d, 1);
    await c.simpan(d, 1);
    final pertama = c.state.daftar.first;
    await c.hapus(pertama);
    expect(c.state.daftar, hasLength(1));
    await c.kembalikan(pertama);
    expect(c.state.daftar, hasLength(2));
    await c.close();
  });

  test('pindai ditolak saat kuota habis', () async {
    final c = buat(sisaKuotaAwal: 0);
    expect(c.pindaiSimulasi(), isNull);
    expect(c.state.sisaKuota, 0);
    await c.close();
  });

  test('peringatan ditutup tersimpan di repository untuk hari ini saja', () async {
    final c = buat();
    await c.tutupPeringatan('gula');
    expect(c.peringatanTerbuka('gula'), isFalse);
    expect(c.peringatanTerbuka('natrium'), isTrue);

    // Cubit baru memuat dari DB di hari yang sama -> tetap tertutup
    final c2 = buat();
    await c2.muat();
    expect(c2.peringatanTerbuka('gula'), isFalse);

    // Hari berikutnya -> terbuka lagi
    sekarang = DateTime(2026, 11, 20, 8);
    await c2.segarkan();
    expect(c2.peringatanTerbuka('gula'), isTrue);

    await c.close();
    await c2.close();
  });

  test('segarkan saat lewat tengah malam mengubah hariAktif dan mereset total hari baru', () async {
    final c = buat();
    await c.simpan(const DrafProduk(nama: 'Teh', gulaG: 15), 1);
    expect(c.state.ringkasan.totalGula, 15);

    sekarang = DateTime(2026, 11, 20, 0, 5);
    await c.segarkan();

    expect(c.state.hariAktif, DateTime(2026, 11, 20));
    expect(c.state.ringkasan.totalGula, 0);
    expect(c.state.ringkasan.jumlahCatatan, 0);
    expect(c.state.daftar, hasLength(1));
    await c.close();
  });

  test('selesaikanPerkenalan menyimpan status ke pengaturan', () async {
    final c = buat();
    expect(await repo.perkenalanSelesai(), isFalse);
    await c.selesaikanPerkenalan();
    expect(await repo.perkenalanSelesai(), isTrue);
    await c.close();
  });
}
