import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../asupan/data/asupan_repository.dart';

class RaporState extends Equatable {
  const RaporState({
    required this.awalMinggu,
    required this.batasMingguIni,
    required this.ringkasan,
    required this.mingguLalu,
    this.penyumbang = const [],
    this.memuat = false,
    this.galat,
  });

  final DateTime awalMinggu;
  final DateTime batasMingguIni;
  final RingkasanMinggu ringkasan;
  final RingkasanMinggu mingguLalu;
  final List<PenyumbangGula> penyumbang;
  final bool memuat;
  final String? galat;

  bool get mingguIni =>
      awalMinggu.year == batasMingguIni.year &&
      awalMinggu.month == batasMingguIni.month &&
      awalMinggu.day == batasMingguIni.day;

  bool get bisaKeMingguBerikutnya => awalMinggu.isBefore(batasMingguIni);

  int get selisihDariMingguLalu => ringkasan.hariGulaDiBawahBatas - mingguLalu.hariGulaDiBawahBatas;

  String get teksPerbandingan {
    if (mingguLalu.hariAdaCatatan == 0) return 'Minggu lalu belum ada catatan.';
    final selisih = selisihDariMingguLalu;
    if (selisih > 0) return 'Naik $selisih hari dari minggu lalu.';
    if (selisih < 0) return 'Turun ${-selisih} hari dari minggu lalu.';
    return 'Sama dengan minggu lalu.';
  }

  RaporState copyWith({
    DateTime? awalMinggu,
    DateTime? batasMingguIni,
    RingkasanMinggu? ringkasan,
    RingkasanMinggu? mingguLalu,
    List<PenyumbangGula>? penyumbang,
    bool? memuat,
    String? galat,
    bool hapusGalat = false,
  }) =>
      RaporState(
        awalMinggu: awalMinggu ?? this.awalMinggu,
        batasMingguIni: batasMingguIni ?? this.batasMingguIni,
        ringkasan: ringkasan ?? this.ringkasan,
        mingguLalu: mingguLalu ?? this.mingguLalu,
        penyumbang: penyumbang ?? this.penyumbang,
        memuat: memuat ?? this.memuat,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [
        awalMinggu,
        batasMingguIni,
        ringkasan,
        mingguLalu,
        penyumbang,
        memuat,
        galat,
      ];
}

/// Mengelola data rapor mingguan (Senin-Minggu lokal) dari AsupanRepository.
class RaporCubit extends Cubit<RaporState> {
  RaporCubit(this._repo, {DateTime Function()? jam})
      : _jam = jam ?? DateTime.now,
        super(_keadaanAwal((jam ?? DateTime.now)()));

  final AsupanRepository _repo;
  final DateTime Function() _jam;

  static RaporState _keadaanAwal(DateTime sekarang) {
    final senin = awalMinggu(sekarang);
    final seninLalu = senin.subtract(const Duration(days: 7));
    return RaporState(
      awalMinggu: senin,
      batasMingguIni: senin,
      ringkasan: RingkasanMinggu(awalMinggu: senin, akhirMinggu: senin.add(const Duration(days: 6))),
      mingguLalu: RingkasanMinggu(awalMinggu: seninLalu, akhirMinggu: seninLalu.add(const Duration(days: 6))),
    );
  }

  Future<void> muat({DateTime? awalMingguTujuan}) async {
    final batasSekarang = awalMinggu(_jam());
    final target = awalMinggu(awalMingguTujuan ?? state.awalMinggu);
    final minggu = target.isAfter(batasSekarang) ? batasSekarang : target;
    emit(state.copyWith(awalMinggu: minggu, batasMingguIni: batasSekarang, memuat: true, hapusGalat: true));
    try {
      final seninLalu = minggu.subtract(const Duration(days: 7));
      final ringkasan = await _repo.ringkasanMinggu(minggu);
      final mingguLalu = await _repo.ringkasanMinggu(seninLalu);
      final penyumbang = await _repo.penyumbangGulaMinggu(minggu);
      if (isClosed) return;
      emit(
        state.copyWith(
          awalMinggu: minggu,
          batasMingguIni: batasSekarang,
          ringkasan: ringkasan,
          mingguLalu: mingguLalu,
          penyumbang: penyumbang,
          memuat: false,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuat: false, galat: 'Gagal memuat rapor mingguan.'));
    }
  }

  Future<void> mingguSebelumnya() => muat(awalMingguTujuan: state.awalMinggu.subtract(const Duration(days: 7)));

  Future<void> mingguBerikutnya() async {
    if (!state.bisaKeMingguBerikutnya) return;
    await muat(awalMingguTujuan: state.awalMinggu.add(const Duration(days: 7)));
  }
}
