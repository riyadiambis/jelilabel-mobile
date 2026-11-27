import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/pengingat_repository.dart';
import '../domain/layanan_notifikasi.dart';
import '../domain/pengaturan_pengingat.dart';

class PengingatState extends Equatable {
  const PengingatState({
    this.pengaturan = const PengaturanPengingat(),
    this.sudahMuat = false,
    this.memproses = false,
    this.izinDitolak = false,
    this.galat,
  });

  final PengaturanPengingat pengaturan;
  final bool sudahMuat;
  final bool memproses;
  final bool izinDitolak;
  final String? galat;

  bool get aktif => pengaturan.aktif;
  String get jamTeks => pengaturan.jamTeks;

  PengingatState copyWith({
    PengaturanPengingat? pengaturan,
    bool? sudahMuat,
    bool? memproses,
    bool? izinDitolak,
    String? galat,
    bool hapusGalat = false,
  }) =>
      PengingatState(
        pengaturan: pengaturan ?? this.pengaturan,
        sudahMuat: sudahMuat ?? this.sudahMuat,
        memproses: memproses ?? this.memproses,
        izinDitolak: izinDitolak ?? this.izinDitolak,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [pengaturan, sudahMuat, memproses, izinDitolak, galat];
}

/// Mengelola pengaturan sakelar, jam pengingat, izin notifikasi, dan penjadwalan ulang harian (F-16).
class PengingatCubit extends Cubit<PengingatState> {
  PengingatCubit(
    this._repo,
    this._notifikasi, {
    DateTime Function()? jam,
  })  : _jam = jam ?? DateTime.now,
        super(const PengingatState());

  final PengingatRepository _repo;
  final LayananNotifikasi _notifikasi;
  final DateTime Function() _jam;

  Future<void> muat() async {
    try {
      final pengaturan = await _repo.bacaPengaturan();
      await _terapkanJadwal(pengaturan);
      if (isClosed) return;
      emit(
        PengingatState(
          pengaturan: pengaturan,
          sudahMuat: true,
          memproses: state.memproses,
          izinDitolak: state.izinDitolak,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal memuat pengingat.'));
    }
  }

  Future<bool> ubahAktif(bool aktifBaru) async {
    if (state.memproses) return false;
    emit(state.copyWith(memproses: true, izinDitolak: false, hapusGalat: true));
    try {
      if (aktifBaru) {
        final diizinkan = await _notifikasi.mintaIzinNotifikasi();
        if (!diizinkan) {
          final mati = state.pengaturan.copyWith(aktif: false);
          await _repo.simpanPengaturan(mati);
          await _notifikasi.batalkan(idNotifikasiPengingat);
          if (!isClosed) {
            emit(
              PengingatState(
                pengaturan: mati,
                sudahMuat: true,
                memproses: false,
                izinDitolak: true,
              ),
            );
          }
          return false;
        }
      }

      final terbaru = state.pengaturan.copyWith(aktif: aktifBaru);
      await _repo.simpanPengaturan(terbaru);
      await _terapkanJadwal(terbaru);
      if (!isClosed) {
        emit(
          PengingatState(
            pengaturan: terbaru,
            sudahMuat: true,
            memproses: false,
            izinDitolak: false,
          ),
        );
      }
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memproses: false, galat: 'Gagal memperbarui pengingat.'));
      return false;
    }
  }

  Future<void> ubahJam(int jam, int menit) async {
    if (state.memproses) return;
    emit(state.copyWith(memproses: true, hapusGalat: true));
    try {
      final terbaru = state.pengaturan.copyWith(jam: jam, menit: menit);
      await _repo.simpanPengaturan(terbaru);
      await _terapkanJadwal(terbaru);
      if (!isClosed) {
        emit(
          PengingatState(
            pengaturan: terbaru,
            sudahMuat: true,
            memproses: false,
            izinDitolak: state.izinDitolak,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memproses: false, galat: 'Gagal menyimpan jam pengingat.'));
    }
  }

  Future<void> jadwalkanUlang() async {
    try {
      final pengaturan = state.sudahMuat ? state.pengaturan : await _repo.bacaPengaturan();
      await _terapkanJadwal(pengaturan);
    } catch (_) {
      // Penjadwalan ulang diam-diam saat sinkronisasi tidak boleh mengganggu alur asupan.
    }
  }

  Future<void> resetKosong() async {
    try {
      await _notifikasi.batalkan(idNotifikasiPengingat);
    } catch (_) {
      // Abaikan kegagalan pembatalan saat reset data.
    }
    if (!isClosed) {
      emit(const PengingatState(sudahMuat: true));
    }
  }

  Future<void> _terapkanJadwal(PengaturanPengingat pengaturan) async {
    if (!pengaturan.aktif) {
      await _notifikasi.batalkan(idNotifikasiPengingat);
      return;
    }
    final sekarang = _jam();
    final sudahAda = await _repo.adaCatatanPadaTanggal(sekarang);
    final jadwal = hitungJadwalBerikutnya(
      sekarang: sekarang,
      jam: pengaturan.jam,
      menit: pengaturan.menit,
      sudahAdaCatatanHariIni: sudahAda,
    );
    await _notifikasi.jadwalkanHarianInexact(
      id: idNotifikasiPengingat,
      judul: judulPengingatHarian,
      isi: teksPengingatHarian,
      waktuLokal: jadwal.waktu,
      ulangiHarian: jadwal.ulangiHarian,
      payload: '/beranda',
    );
  }
}
