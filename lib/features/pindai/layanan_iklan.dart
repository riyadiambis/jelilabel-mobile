/// Sumber bonus kuota lewat video berhadiah (*Rewarded Video*).
///
/// Implementasi produksi nantinya memakai `google_mobile_ads` (`RewardedAd`)
/// dengan bonus yang divalidasi lewat Server-Side Verification (SSV) di Cloud Functions (`K-9 Opsi A`).
/// Implementasi simulasi hanya untuk pengembangan/tes dan tidak boleh aktif di rilis.
abstract interface class LayananIklanKuota {
  Future<bool> tampilkanVideoHadiah();
}

/// Implementasi simulasi lokal sementara sebelum AdMob App ID dan Firebase aktif.
/// Tidak boleh aktif di rilis produksi.
class LayananIklanSimulasi implements LayananIklanKuota {
  const LayananIklanSimulasi({
    this.berhasil = true,
    this.jeda = const Duration(milliseconds: 800),
  });

  final bool berhasil;
  final Duration jeda;

  @override
  Future<bool> tampilkanVideoHadiah() async {
    if (jeda > Duration.zero) {
      await Future<void>.delayed(jeda);
    }
    return berhasil;
  }
}
