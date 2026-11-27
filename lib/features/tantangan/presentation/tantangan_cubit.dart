import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ambang.dart';
import '../../profil/data/profil_repository.dart';
import '../data/tantangan_repository.dart';
import '../domain/jenis_tantangan.dart';

class TantanganState extends Equatable {
  const TantanganState({
    this.berjalan,
    this.berakhirTerbaru,
    this.lencana = const [],
    this.ucapanTercapai,
    this.memuat = false,
    this.menyimpan = false,
    this.galat,
  });

  final KemajuanTantangan? berjalan;
  final KemajuanTantangan? berakhirTerbaru;
  final List<LencanaTantangan> lencana;
  final LencanaTantangan? ucapanTercapai;
  final bool memuat;
  final bool menyimpan;
  final String? galat;

  bool get adaBerjalan => berjalan != null;

  TantanganState copyWith({
    KemajuanTantangan? berjalan,
    bool hapusBerjalan = false,
    KemajuanTantangan? berakhirTerbaru,
    bool hapusBerakhir = false,
    List<LencanaTantangan>? lencana,
    LencanaTantangan? ucapanTercapai,
    bool hapusUcapan = false,
    bool? memuat,
    bool? menyimpan,
    String? galat,
    bool hapusGalat = false,
  }) =>
      TantanganState(
        berjalan: hapusBerjalan ? null : (berjalan ?? this.berjalan),
        berakhirTerbaru: hapusBerakhir ? null : (berakhirTerbaru ?? this.berakhirTerbaru),
        lencana: lencana ?? this.lencana,
        ucapanTercapai: hapusUcapan ? null : (ucapanTercapai ?? this.ucapanTercapai),
        memuat: memuat ?? this.memuat,
        menyimpan: menyimpan ?? this.menyimpan,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [
        berjalan,
        berakhirTerbaru,
        lencana,
        ucapanTercapai,
        memuat,
        menyimpan,
        galat,
      ];
}

/// Mengelola status tantangan berjalan, pilihan tantangan, dan daftar lencana.
class TantanganCubit extends Cubit<TantanganState> {
  TantanganCubit(
    this._repo, {
    DateTime Function()? jam,
    ProfilRepository? profilRepository,
  })  : _jam = jam ?? DateTime.now,
        _profilRepo = profilRepository,
        super(const TantanganState());

  final TantanganRepository _repo;
  final DateTime Function() _jam;
  final ProfilRepository? _profilRepo;

  Future<void> muat() async {
    emit(state.copyWith(memuat: true, hapusGalat: true));
    try {
      final batas = await _profilRepo?.bacaBatasAktif() ?? BatasHarian.kemenkes;
      final status = await _repo.bacaStatus(waktuSekarang: _jam(), batas: batas);
      if (isClosed) return;
      emit(
        TantanganState(
          berjalan: status.berjalan,
          berakhirTerbaru: status.berakhirTerbaru,
          lencana: status.lencana,
          ucapanTercapai: status.ucapanTercapai,
          memuat: false,
          menyimpan: state.menyimpan,
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(memuat: false, galat: 'Gagal memuat tantangan.'));
      }
    }
  }

  Future<bool> mulai(JenisTantangan jenis) async {
    if (state.menyimpan || state.adaBerjalan) return false;
    emit(state.copyWith(menyimpan: true, hapusGalat: true));
    try {
      await _repo.mulaiTantangan(jenis, waktuSekarang: _jam());
      final batas = await _profilRepo?.bacaBatasAktif() ?? BatasHarian.kemenkes;
      final status = await _repo.bacaStatus(waktuSekarang: _jam(), batas: batas);
      if (isClosed) return true;
      emit(
        TantanganState(
          berjalan: status.berjalan,
          berakhirTerbaru: status.berakhirTerbaru,
          lencana: status.lencana,
          ucapanTercapai: status.ucapanTercapai,
          memuat: false,
          menyimpan: false,
        ),
      );
      return true;
    } on StateError {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Masih ada tantangan yang sedang berjalan.'));
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Gagal memulai tantangan.'));
      }
      return false;
    }
  }

  Future<void> tandaiUcapanTercapai(int id) async {
    if (state.ucapanTercapai?.id == id) {
      emit(state.copyWith(hapusUcapan: true));
    }
    try {
      await _repo.tandaiUcapanTercapai(id);
    } catch (_) {
      // Abaikan gagal tulis non-kritis agar dialog tidak memblokir pengguna.
    }
  }
}
