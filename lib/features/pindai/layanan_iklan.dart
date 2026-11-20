/// Abstraksi layanan iklan video berhadiah (*Rewarded Video*) untuk menambah kuota pindai.
///
/// Implementasi produksi nantinya memakai `google_mobile_ads` (`RewardedAd`)
/// disertai verifikasi Server-Side Verification (SSV) lewat Cloud Functions (`K-9 Opsi A`).
abstract interface class LayananIklanKuota {
  Future<bool> tampilkanVideoHadiah();
}

/// Implementasi simulasi lokal sementara sebelum AdMob App ID dan Firebase aktif.
class LayananIklanSimulasi implements LayananIklanKuota {
  const LayananIklanSimulasi({this.berhasil = true});

  final bool berhasil;

  @override
  Future<bool> tampilkanVideoHadiah() async => berhasil;
}
