import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';

void main() {
  final jam = DateTime(2026, 11, 19, 10, 15);
  AsupanCubit buat() => AsupanCubit(jam: () => jam);

  test('simpan menambah total hari ini sesuai porsi', () {
    final c = buat();
    final draf = c.pindaiSimulasi()!;
    c.simpan(draf, 2);
    expect(c.state.totalGula(jam), 24);
    expect(c.state.totalNatrium(jam), 190);
    expect(c.state.totalGula(DateTime(2026, 11, 18)), 0);
  });

  test('kuota berkurang hanya saat label terbaca', () {
    final c = buat();
    for (var i = 0; i < 4; i++) {
      expect(c.pindaiSimulasi(), isNotNull);
    }
    expect(c.state.sisaKuota, 11);
    expect(c.pindaiSimulasi(), isNull, reason: 'percobaan ke-5 disimulasikan gagal');
    expect(c.state.sisaKuota, 11);
  });

  test('nilai null tidak dijumlahkan sebagai 0 dan tetap null di konsumsi', () {
    final c = buat();
    c.simpan(const DrafProduk(nama: 'Keripik', natriumMg: 300), 1);
    expect(c.state.daftar.single.gulaG, isNull);
    expect(c.state.totalNatrium(jam), 300);
  });

  test('hapus lalu kembalikan', () {
    final c = buat();
    c.simpan(const DrafProduk(nama: 'Teh', gulaG: 20), 1);
    final k = c.state.daftar.single;
    c.hapus(k);
    expect(c.state.daftar, isEmpty);
    c.kembalikan(k);
    expect(c.state.daftar, [k]);
  });

  test('hapus satu dari dua catatan yang sama persis', () {
    final c = buat();
    const d = DrafProduk(nama: 'Teh', gulaG: 20);
    c.simpan(d, 1);
    c.simpan(d, 1);
    final pertama = c.state.daftar.first;
    c.hapus(pertama);
    expect(c.state.daftar.length, 1);
    c.kembalikan(pertama);
    c.kembalikan(pertama);
    expect(c.state.daftar.length, 2);
  });

  test('pindai ditolak saat kuota habis', () {
    final c = AsupanCubit(awal: const AsupanState(sisaKuota: 0), jam: () => jam);
    expect(c.pindaiSimulasi(), isNull);
    expect(c.state.sisaKuota, 0);
  });

  test('peringatan ditutup hanya untuk hari ini', () {
    var sekarang = jam;
    final c = AsupanCubit(jam: () => sekarang);
    c.tutupPeringatan('gula');
    expect(c.peringatanTerbuka('gula'), isFalse);
    expect(c.peringatanTerbuka('natrium'), isTrue);
    sekarang = DateTime(2026, 11, 20, 8);
    expect(c.peringatanTerbuka('gula'), isTrue);
  });
}
