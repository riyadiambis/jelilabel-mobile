import 'package:equatable/equatable.dart';

/// ID langganan di Play Console (ISSUE-23). Base plan: [BasePlan].
const idProdukPlus = 'jelilabel_plus';

enum BasePlan {
  bulanan('bulanan', '1 bulan'),
  enamBulan('enam-bulan', '6 bulan');

  const BasePlan(this.id, this.periode);

  /// ID base plan di Play Console.
  final String id;
  final String periode;
}

/// Satu pilihan harga. [harga] sudah terformat dari Play (bukan string tetap).
class PaketPlus extends Equatable {
  const PaketPlus({required this.basePlan, required this.harga});

  final BasePlan basePlan;
  final String harga;

  @override
  List<Object?> get props => [basePlan, harga];
}

enum HasilBeli { berhasil, batal, gagal, tertunda }

/// Satu-satunya sumber status JeliLabel Plus (disuntik get_it, bisa di-mock).
abstract class LayananLangganan {
  /// Memuat status tersimpan, mendengarkan pembelian, lalu mengecek ulang ke Play.
  Future<void> inisialisasi();

  bool get plusAktif;

  /// Emisi `true` saat Plus aktif, `false` saat berakhir atau tidak ditemukan lagi.
  Stream<bool> get statusPlus;

  /// Kosong bila Play tidak tersedia atau produk belum dibuat.
  Future<List<PaketPlus>> muatProduk();

  Future<HasilBeli> beli(BasePlan basePlan);

  /// Mengecek ulang pembelian di Play; mengembalikan status Plus terbaru.
  Future<bool> pulihkan();

  Future<void> tutup();
}

/// Bawaan saat Play tidak dipakai (tes, mode simulasi): selalu gratis, produk tidak tersedia.
class LayananLanggananSimulasi implements LayananLangganan {
  const LayananLanggananSimulasi();

  @override
  Future<void> inisialisasi() async {}

  @override
  bool get plusAktif => false;

  @override
  Stream<bool> get statusPlus => const Stream<bool>.empty();

  @override
  Future<List<PaketPlus>> muatProduk() async => const [];

  @override
  Future<HasilBeli> beli(BasePlan basePlan) async => HasilBeli.gagal;

  @override
  Future<bool> pulihkan() async => false;

  @override
  Future<void> tutup() async {}
}
