import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profil_repository.dart';
import '../domain/profil_batas.dart';

class ProfilState extends Equatable {
  const ProfilState({
    this.profil = ProfilPengguna.kosong,
    this.batas = BatasHarian.kemenkes,
    this.memuat = false,
    this.menyimpan = false,
    this.galat,
  });

  final ProfilPengguna profil;
  final BatasHarian batas;
  final bool memuat;
  final bool menyimpan;
  final String? galat;

  ProfilState copyWith({
    ProfilPengguna? profil,
    BatasHarian? batas,
    bool? memuat,
    bool? menyimpan,
    String? galat,
    bool hapusGalat = false,
  }) =>
      ProfilState(
        profil: profil ?? this.profil,
        batas: batas ?? this.batas,
        memuat: memuat ?? this.memuat,
        menyimpan: menyimpan ?? this.menyimpan,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [profil, batas, memuat, menyimpan, galat];
}

/// Satu sumber status profil singkat dan [BatasHarian] aktif di seluruh aplikasi.
class ProfilCubit extends Cubit<ProfilState> {
  ProfilCubit(this._repo) : super(const ProfilState());

  final ProfilRepository _repo;

  Future<void> muat() async {
    emit(state.copyWith(memuat: true, hapusGalat: true));
    try {
      final profil = await _repo.bacaProfil();
      if (isClosed) return;
      emit(
        ProfilState(
          profil: profil,
          batas: profil.batasHarian,
          memuat: false,
          menyimpan: state.menyimpan,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuat: false, galat: 'Gagal memuat profil.'));
    }
  }

  Future<bool> simpan(ProfilPengguna profil) async {
    if (state.menyimpan) return false;
    emit(state.copyWith(menyimpan: true, hapusGalat: true));
    try {
      await _repo.simpanProfil(profil);
      if (isClosed) return true;
      emit(
        ProfilState(
          profil: profil,
          batas: profil.batasHarian,
          memuat: false,
          menyimpan: false,
        ),
      );
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Gagal menyimpan batas harian.'));
      }
      return false;
    }
  }

  void resetKosong() {
    if (isClosed) return;
    emit(const ProfilState());
  }
}
