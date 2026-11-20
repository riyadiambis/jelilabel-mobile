import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/ambang.dart';

/// Hasil baca label (per sajian), masih draf sampai pengguna menekan Simpan.
class DrafProduk extends Equatable {
  const DrafProduk({
    required this.nama,
    this.gulaG,
    this.natriumMg,
    this.takaranJumlah,
    this.takaranSatuan,
    this.sajianPerKemasan,
    this.cekLagiNatrium = false,
  });

  final String nama;
  final double? gulaG;
  final double? natriumMg;
  final double? takaranJumlah;
  final String? takaranSatuan;
  final double? sajianPerKemasan;
  final bool cekLagiNatrium;

  static const kosong = DrafProduk(nama: '');

  @override
  List<Object?> get props => [nama, gulaG, natriumMg, takaranJumlah, takaranSatuan, sajianPerKemasan, cekLagiNatrium];
}

/// Satu kali makan/minum. Nilai disalin saat simpan (SCHEMA.sql: konsumsi).
class Konsumsi extends Equatable {
  const Konsumsi({
    required this.nama,
    required this.jumlahSajian,
    required this.gulaG,
    required this.natriumMg,
    required this.waktu,
  });

  final String nama;
  final double jumlahSajian;
  final double? gulaG;
  final double? natriumMg;
  final DateTime waktu;

  StatusGizi get status => statusPorsi(gulaG, natriumMg);

  @override
  List<Object?> get props => [nama, jumlahSajian, gulaG, natriumMg, waktu];
}

bool hariSama(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class AsupanState extends Equatable {
  const AsupanState({this.daftar = const [], this.sisaKuota = kuotaGratisMingguan, this.peringatanDitutup = const {}});

  static const kuotaGratisMingguan = 15;

  /// Terbaru di depan.
  final List<Konsumsi> daftar;
  final int sisaKuota;

  /// Kunci 'gula-YYYY-MM-DD' / 'natrium-YYYY-MM-DD' (F-08: sekali per zat per hari).
  final Set<String> peringatanDitutup;

  List<Konsumsi> padaTanggal(DateTime hari) => daftar.where((k) => hariSama(k.waktu, hari)).toList();

  // shortcut: nilai null dilewati, bukan dianggap 0 (FITUR-03 F-05).
  double totalGula(DateTime hari) => padaTanggal(hari).fold(0, (s, k) => s + (k.gulaG ?? 0));
  double totalNatrium(DateTime hari) => padaTanggal(hari).fold(0, (s, k) => s + (k.natriumMg ?? 0));

  AsupanState copyWith({List<Konsumsi>? daftar, int? sisaKuota, Set<String>? peringatanDitutup}) => AsupanState(
        daftar: daftar ?? this.daftar,
        sisaKuota: sisaKuota ?? this.sisaKuota,
        peringatanDitutup: peringatanDitutup ?? this.peringatanDitutup,
      );

  @override
  List<Object?> get props => [daftar, sisaKuota, peringatanDitutup];
}

/// shortcut: data hanya di memori, hilang saat aplikasi ditutup. Diganti sqflite di ISSUE data.
class AsupanCubit extends Cubit<AsupanState> {
  AsupanCubit({AsupanState awal = const AsupanState(), DateTime Function()? jam})
      : _jam = jam ?? DateTime.now,
        super(awal);

  final DateTime Function() _jam;
  int _percobaanPindai = 0;

  DateTime get sekarang => _jam();

  /// Simulasi pindai (belum Gemini). Percobaan ke-5, 10, dst. gagal agar layar galat bisa dicoba.
  /// Kuota hanya berkurang bila label terbaca (PRD 14.2).
  DrafProduk? pindaiSimulasi() {
    _percobaanPindai++;
    if (_percobaanPindai % 5 == 0) return null;
    emit(state.copyWith(sisaKuota: (state.sisaKuota - 1).clamp(0, AsupanState.kuotaGratisMingguan)));
    return const DrafProduk(
      nama: 'Susu UHT Cokelat',
      gulaG: 12,
      natriumMg: 95,
      takaranJumlah: 200,
      takaranSatuan: 'ml',
      sajianPerKemasan: 1,
      cekLagiNatrium: true,
    );
  }

  void simpan(DrafProduk draf, double jumlahSajian) {
    assert(jumlahSajian > 0);
    final k = Konsumsi(
      nama: draf.nama,
      jumlahSajian: jumlahSajian,
      gulaG: draf.gulaG == null ? null : draf.gulaG! * jumlahSajian,
      natriumMg: draf.natriumMg == null ? null : draf.natriumMg! * jumlahSajian,
      waktu: sekarang,
    );
    emit(state.copyWith(daftar: [k, ...state.daftar]));
  }

  void hapus(Konsumsi k) => emit(state.copyWith(daftar: state.daftar.where((x) => x != k).toList()));

  void kembalikan(Konsumsi k) {
    final baru = [...state.daftar, k]..sort((a, b) => b.waktu.compareTo(a.waktu));
    emit(state.copyWith(daftar: baru));
  }

  void tutupPeringatan(String zat) {
    final h = sekarang;
    emit(state.copyWith(peringatanDitutup: {...state.peringatanDitutup, '$zat-${h.year}-${h.month}-${h.day}'}));
  }

  bool peringatanTerbuka(String zat) {
    final h = sekarang;
    return !state.peringatanDitutup.contains('$zat-${h.year}-${h.month}-${h.day}');
  }
}
