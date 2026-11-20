import 'package:equatable/equatable.dart';

import '../asupan/data/asupan_repository.dart';
import 'kontrak_ocr.dart';

class HasilPindai extends Equatable {
  const HasilPindai.berhasil({required DrafProduk this.draf, this.sisaKuotaServer}) : galat = null;
  const HasilPindai.gagal({required GalatPindai this.galat, this.sisaKuotaServer}) : draf = null;

  final DrafProduk? draf;
  final GalatPindai? galat;
  final int? sisaKuotaServer;

  bool get berhasil => draf != null;

  @override
  List<Object?> get props => [draf, galat, sisaKuotaServer];
}

/// Abstraksi pemindai label gizi.
///
/// Implementasi produksi di laptop PM memakai `google_mlkit_document_scanner`,
/// kompresi JPEG (sisi terpanjang <= 1600 px, <= 1 MB), dan memanggil Cloud Functions
/// `pindaiLabelGizi` (Firebase AI Logic `K-9 Opsi A`), lalu menjadikan `kuota.sisa`
/// dari server sebagai sumber kebenaran sisa kuota.
abstract interface class PemindaiLabel {
  Future<HasilPindai> pindai({required int sisaKuotaLokal});
}

/// Implementasi simulasi lokal sementara sebelum paket ML Kit & Firebase dipasang.
class PemindaiLabelSimulasi implements PemindaiLabel {
  PemindaiLabelSimulasi();

  int _percobaan = 0;

  @override
  Future<HasilPindai> pindai({required int sisaKuotaLokal}) async {
    if (sisaKuotaLokal <= 0) {
      return const HasilPindai.gagal(galat: GalatPindai.resourceExhausted);
    }
    _percobaan++;
    if (_percobaan % 5 == 0) {
      return const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca);
    }
    return const HasilPindai.berhasil(
      draf: DrafProduk(
        nama: 'Susu UHT Cokelat',
        gulaG: 12,
        natriumMg: 95,
        takaranJumlah: 200,
        takaranSatuan: 'ml',
        sajianPerKemasan: 1,
        cekLagiNatrium: true,
      ),
    );
  }
}
