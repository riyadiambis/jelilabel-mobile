import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/sesi_olahraga.dart';
import '../domain/sumber_aktivitas.dart';

DateTime _awalHari(DateTime d) {
  final l = d.isUtc ? d.toLocal() : d;
  return DateTime(l.year, l.month, l.day);
}

class AktivitasState extends Equatable {
  const AktivitasState({
    this.statusPerangkat = StatusHealthConnect.tidakDidukung,
    this.terhubung = false,
    this.langkahHariIni,
    this.sesi = const [],
    this.memuat = false,
    this.memintaIzin = false,
  });

  final StatusHealthConnect statusPerangkat;
  final bool terhubung;
  final int? langkahHariIni;
  final List<SesiOlahraga> sesi;
  final bool memuat;
  final bool memintaIzin;

  AktivitasState copyWith({
    StatusHealthConnect? statusPerangkat,
    bool? terhubung,
    int? langkahHariIni,
    bool hapusLangkah = false,
    List<SesiOlahraga>? sesi,
    bool? memuat,
    bool? memintaIzin,
  }) =>
      AktivitasState(
        statusPerangkat: statusPerangkat ?? this.statusPerangkat,
        terhubung: terhubung ?? this.terhubung,
        langkahHariIni: hapusLangkah ? null : (langkahHariIni ?? this.langkahHariIni),
        sesi: sesi ?? this.sesi,
        memuat: memuat ?? this.memuat,
        memintaIzin: memintaIzin ?? this.memintaIzin,
      );

  @override
  List<Object?> get props => [
        statusPerangkat,
        terhubung,
        langkahHariIni,
        sesi,
        memuat,
        memintaIzin,
      ];
}

/// Mengelola status koneksi Health Connect, langkah hari ini, dan sesi olahraga terkini.
class AktivitasCubit extends Cubit<AktivitasState> {
  AktivitasCubit(this._sumber, {DateTime Function()? jam})
      : _jam = jam ?? DateTime.now,
        super(const AktivitasState());

  final SumberAktivitas _sumber;
  final DateTime Function() _jam;

  Future<void> muat() async {
    final hari = _awalHari(_jam());
    if (!state.memuat && !state.terhubung && state.langkahHariIni == null && state.sesi.isEmpty) {
      emit(state.copyWith(memuat: true));
    }
    try {
      final status = await _sumber.statusPerangkat();
      final tersedia = status == StatusHealthConnect.tersedia && await _sumber.tersedia();
      final diizinkan = tersedia ? await _sumber.sudahDiizinkan() : false;
      final terhubung = tersedia && diizinkan;
      if (!terhubung) {
        if (!isClosed) {
          emit(
            AktivitasState(
              statusPerangkat: status,
              terhubung: false,
              memuat: false,
              memintaIzin: state.memintaIzin,
            ),
          );
        }
        return;
      }

      int? langkah;
      try {
        langkah = await _sumber.langkahHari(hari);
      } catch (_) {
        langkah = null;
      }

      List<SesiOlahraga> daftarSesi = const [];
      try {
        daftarSesi = await _sumber.sesiOlahraga(
          hari.subtract(const Duration(days: 29)),
          hari,
        );
      } catch (_) {
        daftarSesi = const [];
      }

      if (isClosed) return;
      emit(
        AktivitasState(
          statusPerangkat: status,
          terhubung: true,
          langkahHariIni: langkah,
          sesi: daftarSesi,
          memuat: false,
          memintaIzin: state.memintaIzin,
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          AktivitasState(
            statusPerangkat: StatusHealthConnect.tidakDidukung,
            terhubung: false,
            memuat: false,
            memintaIzin: state.memintaIzin,
          ),
        );
      }
    }
  }

  Future<bool> mintaIzin() async {
    if (state.memintaIzin) return false;
    emit(state.copyWith(memintaIzin: true));
    var ok = false;
    try {
      ok = await _sumber.mintaIzin();
    } catch (_) {
      ok = false;
    }
    if (isClosed) return ok;
    emit(state.copyWith(memintaIzin: false));
    await muat();
    return ok;
  }

  Future<void> bukaPlayStore() async {
    try {
      await _sumber.bukaPlayStore();
    } catch (_) {
      // Abaikan galat agar aplikasi tetap stabil.
    }
  }
}
