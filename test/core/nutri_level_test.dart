import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/nutri_level.dart';

void main() {
  group('perkiraanNutriLevel', () {
    test('mengembalikan null untuk satuan bukan ml, takaran null/0/negatif, atau ketiga zat null', () {
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'g', gulaG: 5, natriumMg: 50, lemakJenuhG: 0.5),
        isNull,
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: null, gulaG: 5, natriumMg: 50, lemakJenuhG: 0.5),
        isNull,
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: null, takaranSatuan: 'ml', gulaG: 5, natriumMg: 50, lemakJenuhG: 0.5),
        isNull,
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 0, takaranSatuan: 'ml', gulaG: 5, natriumMg: 50, lemakJenuhG: 0.5),
        isNull,
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: -100, takaranSatuan: 'ml', gulaG: 5, natriumMg: 50, lemakJenuhG: 0.5),
        isNull,
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 200, takaranSatuan: 'ml', laktosaG: 5),
        isNull,
      );
    });

    test('batas tepi gula per 100 mL: <= 1 A, 5 B, 10 C, > 10 D', () {
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 1, natriumMg: 0, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.a),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 1.1, natriumMg: 0, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 5, natriumMg: 0, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 5.1, natriumMg: 0, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.c),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 10, natriumMg: 0, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.c),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 10.1, natriumMg: 0, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.d),
      );
    });

    test('batas tepi natrium per 100 mL: <= 5 A, 120 B, 500 C, > 500 D', () {
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 5, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.a),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 5.1, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 120, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 120.1, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.c),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 500, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.c),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 500.1, lemakJenuhG: 0),
        const HasilNutriLevel(level: LevelNutri.d),
      );
    });

    test('batas tepi lemak jenuh per 100 mL: <= 0,7 A, 1,2 B, 2,8 C, > 2,8 D', () {
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 0, lemakJenuhG: 0.7),
        const HasilNutriLevel(level: LevelNutri.a),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 0, lemakJenuhG: 0.71),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 0, lemakJenuhG: 1.2),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 0, lemakJenuhG: 1.21),
        const HasilNutriLevel(level: LevelNutri.c),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 0, lemakJenuhG: 2.8),
        const HasilNutriLevel(level: LevelNutri.c),
      );
      expect(
        perkiraanNutriLevel(takaranJumlah: 100, takaranSatuan: 'ml', gulaG: 0, natriumMg: 0, lemakJenuhG: 2.81),
        const HasilNutriLevel(level: LevelNutri.d),
      );
    });

    test('konversi ke per 100 mL dan level terburuk yang menang', () {
      // 250 mL: gula 12,5 g (5 g/100ml = B), natrium 300 mg (120 mg/100ml = B), lemak jenuh 3 g (1,2 g/100ml = B)
      expect(
        perkiraanNutriLevel(takaranJumlah: 250, takaranSatuan: 'ml', gulaG: 12.5, natriumMg: 300, lemakJenuhG: 3.0),
        const HasilNutriLevel(level: LevelNutri.b),
      );
      // 200 mL: gula 2 g (1 g/100ml = A), natrium 10 mg (5 mg/100ml = A), lemak jenuh 6 g (3 g/100ml = D) -> D
      expect(
        perkiraanNutriLevel(takaranJumlah: 200, takaranSatuan: 'ml', gulaG: 2, natriumMg: 10, lemakJenuhG: 6),
        const HasilNutriLevel(level: LevelNutri.d),
      );
    });

    test('laktosa dikurangi dari gula dan minimal 0', () {
      // 250 mL susu tawar: gula 12 g - laktosa 10 g = 2 g -> 0,8 g/100 mL (A)
      expect(
        perkiraanNutriLevel(
          takaranJumlah: 250,
          takaranSatuan: 'ml',
          gulaG: 12,
          laktosaG: 10,
          natriumMg: 10,
          lemakJenuhG: 1.5,
        ),
        const HasilNutriLevel(level: LevelNutri.a),
      );
      // Laktosa > gula -> gula bersih 0 (minimal 0) -> A
      expect(
        perkiraanNutriLevel(
          takaranJumlah: 200,
          takaranSatuan: 'ml',
          gulaG: 5,
          laktosaG: 8,
          natriumMg: 0,
          lemakJenuhG: 0,
        ),
        const HasilNutriLevel(level: LevelNutri.a),
      );
    });

    test('zat null diabaikan dan menandai tidakLengkap = true', () {
      final hanyaGula = perkiraanNutriLevel(takaranJumlah: 200, takaranSatuan: 'ml', gulaG: 12);
      expect(hanyaGula, const HasilNutriLevel(level: LevelNutri.c, tidakLengkap: true));

      final tanpaLemakJenuh = perkiraanNutriLevel(
        takaranJumlah: 200,
        takaranSatuan: 'ml',
        gulaG: 2,
        natriumMg: 10,
      );
      expect(tanpaLemakJenuh, const HasilNutriLevel(level: LevelNutri.a, tidakLengkap: true));
    });
  });
}
