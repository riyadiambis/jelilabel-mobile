import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/features/pindai/layanan_iklan.dart';

void main() {
  test('LayananIklanSimulasi mengembalikan true setelah jeda simulasi', () async {
    const layanan = LayananIklanSimulasi(jeda: Duration(milliseconds: 10));
    expect(await layanan.tampilkanVideoHadiah(), isTrue);

    const gagal = LayananIklanSimulasi(berhasil: false, jeda: Duration.zero);
    expect(await gagal.tampilkanVideoHadiah(), isFalse);
  });
}
