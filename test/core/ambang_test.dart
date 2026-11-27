import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/ambang.dart';

void main() {
  group('statusZat (AMBANG-STATUS, batas tepat)', () {
    test('gula', () {
      expect(statusZat(4.9, batasGulaHarianG), StatusGizi.aman);
      expect(statusZat(5, batasGulaHarianG), StatusGizi.waspada);
      expect(statusZat(12.5, batasGulaHarianG), StatusGizi.waspada);
      expect(statusZat(12.6, batasGulaHarianG), StatusGizi.tinggi);
    });
    test('natrium', () {
      expect(statusZat(199, batasNatriumHarianMg), StatusGizi.aman);
      expect(statusZat(200, batasNatriumHarianMg), StatusGizi.waspada);
      expect(statusZat(500, batasNatriumHarianMg), StatusGizi.waspada);
      expect(statusZat(501, batasNatriumHarianMg), StatusGizi.tinggi);
    });
    test('lemak total (tepi 6,7 dan 16,75)', () {
      expect(statusZat(6.6, batasLemakHarianG), StatusGizi.aman);
      expect(statusZat(6.7, batasLemakHarianG), StatusGizi.waspada);
      expect(statusZat(16.75, batasLemakHarianG), StatusGizi.waspada);
      expect(statusZat(16.76, batasLemakHarianG), StatusGizi.tinggi);
      expect(statusZat(null, batasLemakHarianG), StatusGizi.tidakDiketahui);
    });
    test('null tidak diketahui, bukan 0', () {
      expect(statusZat(null, batasGulaHarianG), StatusGizi.tidakDiketahui);
    });
  });

  test('statusPorsi = terburuk dari tiga zat, null dilewati', () {
    expect(statusPorsi(12, 95), StatusGizi.waspada);
    expect(statusPorsi(2, 900), StatusGizi.tinggi);
    expect(statusPorsi(null, 100), StatusGizi.aman);
    expect(statusPorsi(null, null), StatusGizi.tidakDiketahui);
    expect(statusPorsi(2, 50, 17), StatusGizi.tinggi);
    expect(statusPorsi(2, 50, 10), StatusGizi.waspada);
    expect(statusPorsi(2, 50, 3), StatusGizi.aman);
    expect(statusPorsi(null, null, 6.7), StatusGizi.waspada);
    expect(statusPorsi(null, null, null), StatusGizi.tidakDiketahui);
  });

  test('statusHarian', () {
    expect(statusHarian(37, 50), StatusHarian.aman);
    expect(statusHarian(37.5, 50), StatusHarian.hampirBatas);
    expect(statusHarian(50, 50), StatusHarian.hampirBatas);
    expect(statusHarian(50.1, 50), StatusHarian.lewatBatas);
    expect(statusHarian(50, batasLemakHarianG), StatusHarian.aman);
    expect(statusHarian(50.25, batasLemakHarianG), StatusHarian.hampirBatas);
    expect(statusHarian(67, batasLemakHarianG), StatusHarian.hampirBatas);
    expect(statusHarian(67.1, batasLemakHarianG), StatusHarian.lewatBatas);
  });

  test('takaran sendok (G4 G1 L5)', () {
    expect(sendokGaram(2000), 1);
    expect(sendokGula(50), 4);
    expect(sendokMinyak(67), 5);
    expect(sendokMinyak(13.4), 1);
    expect(sendokMinyak(6.7), 0.5);
    expect(teksSendok(12 / 12.5), '1');
    expect(teksSendok(95 / 2000), '< ½');
    expect(teksSendok(3 / 13.4), '< ½');
    expect(teksSendok(0.3), '½');
    expect(teksSendok(1.4), '1,5');
  });

  test('angka memakai koma desimal', () {
    expect(angka(12.5), '12,5');
    expect(angka(38), '38');
    expect(angka(12.96), '13');
    expect(angka(50.4), '50,4');
  });

  group('BatasHarian dan AKG-2019 (ISSUE-18)', () {
    test('tanpa profil memakai batas Kemenkes 50 / 2000 / 67', () {
      final b = hitungBatasHarian();
      expect(b.gulaG, 50);
      expect(b.natriumMg, 2000);
      expect(b.lemakG, 67);
      expect(b.sumber, SumberBatas.kemenkes);
      expect(b.berbedaDariKemenkes, isFalse);
    });

    test('seluruh kelompok umur dan jenis kelamin sesuai AKG-2019', () {
      const harapan = <(KelompokUmur, JenisKelamin, double)>[
        (KelompokUmur.u13_15, JenisKelamin.lakiLaki, 50),
        (KelompokUmur.u16_18, JenisKelamin.lakiLaki, 50),
        (KelompokUmur.u19_29, JenisKelamin.lakiLaki, 50),
        (KelompokUmur.u30_49, JenisKelamin.lakiLaki, 50),
        (KelompokUmur.u50_64, JenisKelamin.lakiLaki, 50),
        (KelompokUmur.u65_80, JenisKelamin.lakiLaki, 45),
        (KelompokUmur.u80Plus, JenisKelamin.lakiLaki, 40),
        (KelompokUmur.u13_15, JenisKelamin.perempuan, 50),
        (KelompokUmur.u16_18, JenisKelamin.perempuan, 50),
        (KelompokUmur.u19_29, JenisKelamin.perempuan, 50),
        (KelompokUmur.u30_49, JenisKelamin.perempuan, 50),
        (KelompokUmur.u50_64, JenisKelamin.perempuan, 45),
        (KelompokUmur.u65_80, JenisKelamin.perempuan, 38),
        (KelompokUmur.u80Plus, JenisKelamin.perempuan, 35),
      ];
      for (final (umur, jk, gulaHarapan) in harapan) {
        final b = hitungBatasHarian(umur: umur, jenisKelamin: jk);
        expect(b.gulaG, gulaHarapan, reason: '${jk.kode} ${umur.kode}');
        expect(b.natriumMg, 2000);
        expect(b.lemakG, 67);
        expect(b.sumber, SumberBatas.pribadi);
      }
    });

    test('batas sendiri (> 0) menimpa nilai zat terkait dan menandai sumber dariDokter', () {
      final b = hitungBatasHarian(
        umur: KelompokUmur.u50_64,
        jenisKelamin: JenisKelamin.perempuan,
        batasSendiriGulaG: 30,
        batasSendiriNatriumMg: 1500,
        batasSendiriLemakG: 0, // <= 0 diabaikan
      );
      expect(b.gulaG, 30);
      expect(b.natriumMg, 1500);
      expect(b.lemakG, 67);
      expect(b.sumber, SumberBatas.dariDokter);
      expect(b.gulaBerbedaDariKemenkes, isTrue);
      expect(b.natriumBerbedaDariKemenkes, isTrue);
      expect(b.lemakBerbedaDariKemenkes, isFalse);
    });

    test('statusPorsi mengikuti batas pribadi', () {
      const batasP80 = BatasHarian(gulaG: 35, sumber: SumberBatas.pribadi);
      // 9 g: dengan Kemenkes 50 g = 18% (Waspada); dengan batas 35 g = 25,7% (Tinggi)
      expect(statusPorsi(9, 100), StatusGizi.waspada);
      expect(statusPorsi(9, 100, null, batasP80), StatusGizi.tinggi);
    });
  });
}
