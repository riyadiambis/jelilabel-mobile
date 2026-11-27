import 'sesi_olahraga.dart';

/// Antarmuka baca-saja untuk data langkah dan sesi olahraga dari Health Connect.
abstract class SumberAktivitas {
  /// Memeriksa apakah Health Connect tersedia di perangkat.
  Future<bool> tersedia();

  /// Status rinci Health Connect di perangkat (tersedia, perlu pasang, atau tidak didukung).
  Future<StatusHealthConnect> statusPerangkat() async =>
      (await tersedia()) ? StatusHealthConnect.tersedia : StatusHealthConnect.perluPasang;

  /// Memeriksa apakah izin baca langkah atau olahraga sudah diberikan.
  Future<bool> sudahDiizinkan() async => tersedia();

  /// Meminta izin baca langkah, sesi olahraga, dan jarak dari Health Connect.
  Future<bool> mintaIzin();

  /// Membuka halaman Health Connect di Play Store (Android 13 ke bawah).
  Future<void> bukaPlayStore() async {}

  /// Jumlah langkah pada tanggal lokal [tanggal], atau null bila tidak tersedia/gagal.
  Future<int?> langkahHari(DateTime tanggal);

  /// Total langkah per tanggal lokal ('YYYY-MM-DD') untuk rentang [dari] s.d. [sampai].
  Future<Map<String, int>> langkahRentang(DateTime dari, DateTime sampai);

  /// Daftar sesi olahraga untuk rentang tanggal lokal [dari] s.d. [sampai].
  Future<List<SesiOlahraga>> sesiOlahraga(DateTime dari, DateTime sampai);
}
