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
    test('null tidak diketahui, bukan 0', () {
      expect(statusZat(null, batasGulaHarianG), StatusGizi.tidakDiketahui);
    });
  });

  test('statusPorsi = terburuk, null dilewati', () {
    expect(statusPorsi(12, 95), StatusGizi.waspada);
    expect(statusPorsi(2, 900), StatusGizi.tinggi);
    expect(statusPorsi(null, 100), StatusGizi.aman);
    expect(statusPorsi(null, null), StatusGizi.tidakDiketahui);
  });

  test('statusHarian', () {
    expect(statusHarian(37, 50), StatusHarian.aman);
    expect(statusHarian(37.5, 50), StatusHarian.hampirBatas);
    expect(statusHarian(50, 50), StatusHarian.hampirBatas);
    expect(statusHarian(50.1, 50), StatusHarian.lewatBatas);
  });

  test('takaran sendok (G4 G1 L5)', () {
    expect(sendokGaram(2000), 1);
    expect(sendokGula(50), 4);
    expect(teksSendok(12 / 12.5), '1');
    expect(teksSendok(95 / 2000), '< ½');
    expect(teksSendok(0.3), '½');
    expect(teksSendok(1.4), '1,5');
  });

  test('angka memakai koma desimal', () {
    expect(angka(12.5), '12,5');
    expect(angka(38), '38');
  });
}
