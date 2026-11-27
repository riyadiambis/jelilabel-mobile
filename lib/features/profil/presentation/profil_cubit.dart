import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profil_repository.dart';
import '../domain/profil_batas.dart';

class ProfilState extends Equatable {
  const ProfilState({
    this.profil = ProfilPengguna.kosong,
    this.daftarProfil = const [],
    this.batas = BatasHarian.kemenkes,
    this.sudahMuat = false,
    this.memuat = false,
    this.menyimpan = false,
    this.galat,
  });

  final ProfilPengguna profil;
  final List<ProfilPengguna> daftarProfil;
  final BatasHarian batas;
  final bool sudahMuat;
  final bool memuat;
  final bool menyimpan;
  final String? galat;

  bool get bisaTambahProfil => daftarProfil.length < maksProfilKeluarga;
  bool get bisaHapusProfil => daftarProfil.length > 1;

  ProfilState copyWith({
    ProfilPengguna? profil,
    List<ProfilPengguna>? daftarProfil,
    BatasHarian? batas,
    bool? sudahMuat,
    bool? memuat,
    bool? menyimpan,
    String? galat,
    bool hapusGalat = false,
  }) =>
      ProfilState(
        profil: profil ?? this.profil,
        daftarProfil: daftarProfil ?? this.daftarProfil,
        batas: batas ?? this.batas,
        sudahMuat: sudahMuat ?? this.sudahMuat,
        memuat: memuat ?? this.memuat,
        menyimpan: menyimpan ?? this.menyimpan,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [profil, daftarProfil, batas, sudahMuat, memuat, menyimpan, galat];
}

/// Satu sumber status profil aktif, daftar anggota keluarga, dan [BatasHarian] di seluruh aplikasi.
class ProfilCubit extends Cubit<ProfilState> {
  ProfilCubit(this._repo) : super(const ProfilState());

  final ProfilRepository _repo;

  Future<void> muat() async {
    emit(state.copyWith(memuat: true, hapusGalat: true));
    try {
      final daftar = await _repo.bacaDaftarProfil();
      final profil = await _repo.bacaProfil();
      if (isClosed) return;
      emit(
        ProfilState(
          profil: profil,
          daftarProfil: daftar,
          batas: profil.batasHarian,
          sudahMuat: true,
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
      final tersimpan = await _repo.simpanProfil(profil);
      final daftar = await _repo.bacaDaftarProfil();
      if (isClosed) return true;
      emit(
        ProfilState(
          profil: tersimpan,
          daftarProfil: daftar,
          batas: tersimpan.batasHarian,
          sudahMuat: true,
          memuat: false,
          menyimpan: false,
        ),
      );
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Gagal menyimpan profil.'));
      }
      return false;
    }
  }

  Future<bool> tambahAnggota(ProfilPengguna profil, {bool jadikanAktif = true}) async {
    if (state.menyimpan) return false;
    emit(state.copyWith(menyimpan: true, hapusGalat: true));
    try {
      final daftarSebelum = await _repo.bacaDaftarProfil();
      if (daftarSebelum.isEmpty) {
        await _repo.pastikanProfilAwal();
      }
      final baru = await _repo.tambahProfil(profil);
      if (jadikanAktif && baru.id != null) {
        await _repo.pilihProfilAktif(baru.id!);
      }
      final daftar = await _repo.bacaDaftarProfil();
      final aktif = await _repo.bacaProfil();
      if (isClosed) return true;
      emit(
        ProfilState(
          profil: aktif,
          daftarProfil: daftar,
          batas: aktif.batasHarian,
          sudahMuat: true,
          memuat: false,
          menyimpan: false,
        ),
      );
      return true;
    } on StateError catch (e) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: e.message));
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Gagal menambah anggota keluarga.'));
      }
      return false;
    }
  }

  Future<bool> pilihProfil(int profilId) async {
    if (state.menyimpan) return false;
    emit(state.copyWith(menyimpan: true, hapusGalat: true));
    try {
      await _repo.pilihProfilAktif(profilId);
      final daftar = await _repo.bacaDaftarProfil();
      final aktif = await _repo.bacaProfil();
      if (isClosed) return true;
      emit(
        ProfilState(
          profil: aktif,
          daftarProfil: daftar,
          batas: aktif.batasHarian,
          sudahMuat: true,
          memuat: false,
          menyimpan: false,
        ),
      );
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Gagal mengganti profil.'));
      }
      return false;
    }
  }

  Future<bool> hapusProfil(int profilId) async {
    if (state.menyimpan) return false;
    emit(state.copyWith(menyimpan: true, hapusGalat: true));
    try {
      await _repo.hapusProfil(profilId);
      final daftar = await _repo.bacaDaftarProfil();
      final aktif = await _repo.bacaProfil();
      if (isClosed) return true;
      emit(
        ProfilState(
          profil: aktif,
          daftarProfil: daftar,
          batas: aktif.batasHarian,
          sudahMuat: true,
          memuat: false,
          menyimpan: false,
        ),
      );
      return true;
    } on StateError catch (e) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: e.message));
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(menyimpan: false, galat: 'Gagal menghapus profil.'));
      }
      return false;
    }
  }

  void resetKosong() {
    if (isClosed) return;
    emit(const ProfilState(sudahMuat: true));
  }
}
