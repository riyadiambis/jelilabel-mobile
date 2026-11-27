import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/ambang.dart';
import '../../core/format.dart';
import '../aktivitas/domain/sumber_aktivitas.dart';
import '../asupan/data/asupan_repository.dart';
import '../profil/data/profil_repository.dart';

class RaporState extends Equatable {
  const RaporState({
    required this.awalMinggu,
    required this.batasMingguIni,
    required this.ringkasan,
    required this.mingguLalu,
    this.hariTerlewati = 7,
    this.penyumbang = const [],
    this.rataLangkahMinggu,
    this.memuat = false,
    this.galat,
  });

  final DateTime awalMinggu;
  final DateTime batasMingguIni;
  final RingkasanMinggu ringkasan;
  final RingkasanMinggu mingguLalu;
  final int hariTerlewati;
  final List<PenyumbangGula> penyumbang;
  final int? rataLangkahMinggu;
  final bool memuat;
  final String? galat;

  bool get mingguIni =>
      awalMinggu.year == batasMingguIni.year &&
      awalMinggu.month == batasMingguIni.month &&
      awalMinggu.day == batasMingguIni.day;

  bool get bisaKeMingguBerikutnya => awalMinggu.isBefore(batasMingguIni);

  int get hariKosong => (hariTerlewati - ringkasan.hariAdaCatatan).clamp(0, 7);

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
    int? hariTerlewati,
    List<PenyumbangGula>? penyumbang,
    int? rataLangkahMinggu,
    bool hapusRataLangkah = false,
    bool? memuat,
    String? galat,
    bool hapusGalat = false,
  }) =>
      RaporState(
        awalMinggu: awalMinggu ?? this.awalMinggu,
        batasMingguIni: batasMingguIni ?? this.batasMingguIni,
        ringkasan: ringkasan ?? this.ringkasan,
        mingguLalu: mingguLalu ?? this.mingguLalu,
        hariTerlewati: hariTerlewati ?? this.hariTerlewati,
        penyumbang: penyumbang ?? this.penyumbang,
        rataLangkahMinggu: hapusRataLangkah ? null : (rataLangkahMinggu ?? this.rataLangkahMinggu),
        memuat: memuat ?? this.memuat,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [
        awalMinggu,
        batasMingguIni,
        ringkasan,
        mingguLalu,
        hariTerlewati,
        penyumbang,
        rataLangkahMinggu,
        memuat,
        galat,
      ];
}

/// Mengelola data rapor mingguan (Senin-Minggu lokal) dari AsupanRepository.
class RaporCubit extends Cubit<RaporState> {
  RaporCubit(
    this._repo, {
    DateTime Function()? jam,
    SumberAktivitas? sumberAktivitas,
    ProfilRepository? profilRepository,
  })  : _jam = jam ?? DateTime.now,
        _sumber = sumberAktivitas,
        _profilRepo = profilRepository,
        super(_keadaanAwal((jam ?? DateTime.now)()));

  final AsupanRepository _repo;
  final DateTime Function() _jam;
  final SumberAktivitas? _sumber;
  final ProfilRepository? _profilRepo;

  static int _hitungHariTerlewati(DateTime minggu, DateTime sekarang) {
    final l = sekarang.isUtc ? sekarang.toLocal() : sekarang;
    final batasSekarang = awalMinggu(l);
    if (minggu.year != batasSekarang.year ||
        minggu.month != batasSekarang.month ||
        minggu.day != batasSekarang.day) {
      return 7;
    }
    final hariIni = DateTime(l.year, l.month, l.day);
    return (hariIni.difference(minggu).inDays + 1).clamp(1, 7);
  }

  static RaporState _keadaanAwal(DateTime sekarang) {
    final senin = awalMinggu(sekarang);
    final seninLalu = senin.subtract(const Duration(days: 7));
    return RaporState(
      awalMinggu: senin,
      batasMingguIni: senin,
      hariTerlewati: _hitungHariTerlewati(senin, sekarang),
      ringkasan: RingkasanMinggu(awalMinggu: senin, akhirMinggu: senin.add(const Duration(days: 6))),
      mingguLalu: RingkasanMinggu(awalMinggu: seninLalu, akhirMinggu: seninLalu.add(const Duration(days: 6))),
    );
  }

  Future<void> muat({DateTime? awalMingguTujuan}) async {
    final sekarang = _jam();
    final batasSekarang = awalMinggu(sekarang);
    final target = awalMinggu(awalMingguTujuan ?? state.awalMinggu);
    final minggu = target.isAfter(batasSekarang) ? batasSekarang : target;
    final hariTerlewati = _hitungHariTerlewati(minggu, sekarang);
    emit(
      state.copyWith(
        awalMinggu: minggu,
        batasMingguIni: batasSekarang,
        hariTerlewati: hariTerlewati,
        memuat: true,
        hapusGalat: true,
      ),
    );
    try {
      final seninLalu = minggu.subtract(const Duration(days: 7));
      final batas = await _profilRepo?.bacaBatasAktif() ?? BatasHarian.kemenkes;
      final ringkasan = await _repo.ringkasanMinggu(minggu, batasGula: batas.gulaG);
      final mingguLalu = await _repo.ringkasanMinggu(seninLalu, batasGula: batas.gulaG);
      final penyumbang = await _repo.penyumbangGulaMinggu(minggu);
      final rataLangkah = await _bacaRataLangkahMinggu(minggu);
      if (isClosed) return;
      emit(
        state.copyWith(
          awalMinggu: minggu,
          batasMingguIni: batasSekarang,
          hariTerlewati: hariTerlewati,
          ringkasan: ringkasan,
          mingguLalu: mingguLalu,
          penyumbang: penyumbang,
          rataLangkahMinggu: rataLangkah,
          hapusRataLangkah: rataLangkah == null,
          memuat: false,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuat: false, galat: 'Gagal memuat rapor mingguan.'));
    }
  }

  Future<int?> _bacaRataLangkahMinggu(DateTime senin) async {
    final sumber = _sumber;
    if (sumber == null) return null;
    try {
      final tersedia = await sumber.tersedia();
      final diizinkan = tersedia ? await sumber.sudahDiizinkan() : false;
      if (!tersedia || !diizinkan) return null;
      final peta = await sumber.langkahRentang(senin, senin.add(const Duration(days: 6)));
      final hariBerisi = peta.values.where((v) => v > 0).toList();
      if (hariBerisi.isEmpty) return 0;
      final total = hariBerisi.reduce((a, b) => a + b);
      return (total / hariBerisi.length).round();
    } catch (_) {
      return null;
    }
  }

  Future<void> mingguSebelumnya() => muat(awalMingguTujuan: state.awalMinggu.subtract(const Duration(days: 7)));

  Future<void> mingguBerikutnya() async {
    if (!state.bisaKeMingguBerikutnya) return;
    await muat(awalMingguTujuan: state.awalMinggu.add(const Duration(days: 7)));
  }
}
