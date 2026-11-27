import 'package:equatable/equatable.dart';

import '../../../core/ambang.dart';

/// Jenis aktivitas olahraga yang diringkas dari Health Connect.
enum JenisOlahraga {
  jalan('Jalan'),
  jogging('Jogging'),
  lari('Lari'),
  lainnya('Olahraga');

  const JenisOlahraga(this.label);
  final String label;
}

/// Status ketersediaan layanan Health Connect di perangkat.
enum StatusHealthConnect {
  tersedia,
  perluPasang,
  tidakDidukung,
}

/// Satu sesi olahraga yang dibaca dari Health Connect (tidak disimpan ke SQLite).
class SesiOlahraga extends Equatable {
  const SesiOlahraga({
    required this.jenis,
    required this.mulai,
    required this.durasi,
    this.jarakMeter,
  });

  final JenisOlahraga jenis;
  final DateTime mulai;
  final Duration durasi;
  final double? jarakMeter;

  DateTime get tanggalLokalObjek {
    final l = mulai.isUtc ? mulai.toLocal() : mulai;
    return DateTime(l.year, l.month, l.day);
  }

  /// Teks ringkas seperti "Jogging · 32 menit · 4,1 km".
  String get teksRingkasan {
    final menit = durasi.inSeconds > 0 && durasi.inMinutes == 0 ? 1 : durasi.inMinutes;
    final bagian = <String>[
      jenis.label,
      '$menit menit',
    ];
    final jarak = jarakMeter;
    if (jarak != null && jarak > 0) {
      if (jarak >= 1000) {
        bagian.add('${angka(jarak / 1000)} km');
      } else {
        bagian.add('${jarak.round()} m');
      }
    }
    return bagian.join(' · ');
  }

  @override
  List<Object?> get props => [jenis, mulai, durasi, jarakMeter];
}
