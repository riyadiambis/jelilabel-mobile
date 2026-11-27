import 'package:equatable/equatable.dart';

const teksPengingatHarian = 'Sudah catat jajanan hari ini? Nuri siap bantu.';
const judulPengingatHarian = 'JeliLabel';
const jamPengingatDefault = 19;
const menitPengingatDefault = 0;
const idNotifikasiPengingat = 1001;

/// Pengaturan pengingat harian lokal (F-16).
class PengaturanPengingat extends Equatable {
  const PengaturanPengingat({
    this.aktif = false,
    this.jam = jamPengingatDefault,
    this.menit = menitPengingatDefault,
  });

  final bool aktif;
  final int jam;
  final int menit;

  String get jamTeks => '${jam.toString().padLeft(2, '0')}.${menit.toString().padLeft(2, '0')}';

  PengaturanPengingat copyWith({
    bool? aktif,
    int? jam,
    int? menit,
  }) =>
      PengaturanPengingat(
        aktif: aktif ?? this.aktif,
        jam: jam ?? this.jam,
        menit: menit ?? this.menit,
      );

  @override
  List<Object?> get props => [aktif, jam, menit];
}

/// Menghitung waktu pengingat lokal berikutnya.
/// Bila hari ini sudah ada catatan, jadwal hari ini dilewati (besok, sekali dulu tanpa ulang otomatis hari ini).
({DateTime waktu, bool ulangiHarian}) hitungJadwalBerikutnya({
  required DateTime sekarang,
  required int jam,
  required int menit,
  required bool sudahAdaCatatanHariIni,
}) {
  final l = sekarang.isUtc ? sekarang.toLocal() : sekarang;
  final hariIniTarget = DateTime(l.year, l.month, l.day, jam, menit);
  if (sudahAdaCatatanHariIni) {
    return (waktu: hariIniTarget.add(const Duration(days: 1)), ulangiHarian: false);
  }
  if (hariIniTarget.isAfter(l)) {
    return (waktu: hariIniTarget, ulangiHarian: true);
  }
  return (waktu: hariIniTarget.add(const Duration(days: 1)), ulangiHarian: true);
}
