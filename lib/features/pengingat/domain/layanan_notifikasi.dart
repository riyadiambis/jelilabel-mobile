/// Kontrak penjadwalan dan izin notifikasi lokal (F-16) agar mudah di-mock lewat get_it.
abstract class LayananNotifikasi {
  Future<void> inisialisasi({void Function(String? payload)? onKetuk});

  Future<String?> payloadPeluncuranAwal();

  Future<bool> mintaIzinNotifikasi();

  Future<void> jadwalkanHarianInexact({
    required int id,
    required String judul,
    required String isi,
    required DateTime waktuLokal,
    required bool ulangiHarian,
    String? payload,
  });

  Future<void> batalkan(int id);
}
