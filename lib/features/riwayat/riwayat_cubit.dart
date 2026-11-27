import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../asupan/data/asupan_repository.dart';

enum RentangRiwayat {
  tujuhHari(7, '7 hari'),
  tigaPuluhHari(30, '30 hari'),
  sembilanPuluhHari(90, '90 hari');

  const RentangRiwayat(this.jumlahHari, this.label);
  final int jumlahHari;
  final String label;
}

class RiwayatState extends Equatable {
  const RiwayatState({
    required this.hariAktif,
    this.rentang = RentangRiwayat.tujuhHari,
    this.offsetMinggu = 0,
    this.ringkasanHarian = const {},
    this.memuat = false,
    this.galat,
  });

  final DateTime hariAktif;
  final RentangRiwayat rentang;
  final int offsetMinggu;
  final Map<String, ({double gula, double natrium, double lemak})> ringkasanHarian;
  final bool memuat;
  final String? galat;

  DateTime get awalRentang => switch (rentang) {
        RentangRiwayat.tujuhHari => awalMinggu(hariAktif).subtract(Duration(days: offsetMinggu * 7)),
        RentangRiwayat.tigaPuluhHari => hariAktif.subtract(const Duration(days: 29)),
        RentangRiwayat.sembilanPuluhHari => hariAktif.subtract(const Duration(days: 89)),
      };

  DateTime get akhirRentang => switch (rentang) {
        RentangRiwayat.tujuhHari => awalRentang.add(const Duration(days: 6)),
        RentangRiwayat.tigaPuluhHari || RentangRiwayat.sembilanPuluhHari => hariAktif,
      };

  List<DateTime> get daftarHari => [
        for (var i = 0; i < rentang.jumlahHari; i++) awalRentang.add(Duration(days: i)),
      ];

  bool get bisaKeMingguBerikutnya => rentang == RentangRiwayat.tujuhHari && offsetMinggu > 0;

  double totalGula(DateTime hari) => ringkasanHarian[tanggalLokal(hari)]?.gula ?? 0;
  double totalNatrium(DateTime hari) => ringkasanHarian[tanggalLokal(hari)]?.natrium ?? 0;
  double totalLemak(DateTime hari) => ringkasanHarian[tanggalLokal(hari)]?.lemak ?? 0;

  RiwayatState copyWith({
    DateTime? hariAktif,
    RentangRiwayat? rentang,
    int? offsetMinggu,
    Map<String, ({double gula, double natrium, double lemak})>? ringkasanHarian,
    bool? memuat,
    String? galat,
    bool hapusGalat = false,
  }) =>
      RiwayatState(
        hariAktif: hariAktif ?? this.hariAktif,
        rentang: rentang ?? this.rentang,
        offsetMinggu: offsetMinggu ?? this.offsetMinggu,
        ringkasanHarian: ringkasanHarian ?? this.ringkasanHarian,
        memuat: memuat ?? this.memuat,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [hariAktif, rentang, offsetMinggu, ringkasanHarian, memuat, galat];
}

/// Mengelola grafik rentang 7/30/90 hari dan navigasi minggu pada layar Riwayat.
class RiwayatCubit extends Cubit<RiwayatState> {
  RiwayatCubit(this._repo, {DateTime Function()? jam})
      : _jam = jam ?? DateTime.now,
        super(RiwayatState(hariAktif: _awalHari((jam ?? DateTime.now)())));

  final AsupanRepository _repo;
  final DateTime Function() _jam;

  static DateTime _awalHari(DateTime d) {
    final l = d.isUtc ? d.toLocal() : d;
    return DateTime(l.year, l.month, l.day);
  }

  Future<void> muatGrafik({RentangRiwayat? rentang, int? offsetMinggu}) async {
    final hari = _awalHari(_jam());
    final rentangBaru = rentang ?? state.rentang;
    final offsetBaru = (offsetMinggu ?? state.offsetMinggu).clamp(0, 520);
    final targetState = state.copyWith(
      hariAktif: hari,
      rentang: rentangBaru,
      offsetMinggu: rentangBaru == RentangRiwayat.tujuhHari ? offsetBaru : 0,
      memuat: true,
      hapusGalat: true,
    );
    emit(targetState);
    try {
      final peta = await _repo.ringkasanRentang(targetState.awalRentang, targetState.akhirRentang);
      if (isClosed) return;
      emit(targetState.copyWith(ringkasanHarian: peta, memuat: false));
    } catch (_) {
      if (!isClosed) emit(targetState.copyWith(memuat: false, galat: 'Gagal memuat grafik riwayat.'));
    }
  }

  Future<void> pilihRentang(RentangRiwayat rentang) => muatGrafik(rentang: rentang, offsetMinggu: 0);

  Future<void> mingguSebelumnya() => muatGrafik(offsetMinggu: state.offsetMinggu + 1);

  Future<void> mingguBerikutnya() async {
    if (!state.bisaKeMingguBerikutnya) return;
    await muatGrafik(offsetMinggu: state.offsetMinggu - 1);
  }
}
