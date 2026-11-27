import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/layanan_langganan.dart';

class LanggananState extends Equatable {
  const LanggananState({
    this.memuat = true,
    this.paket = const [],
    this.pilihan = BasePlan.bulanan,
    this.proses = false,
    this.plus = false,
    this.pesan,
  });

  final bool memuat;
  final List<PaketPlus> paket;
  final BasePlan pilihan;

  /// Beli atau pulihkan sedang berjalan: tombol dikunci.
  final bool proses;
  final bool plus;

  /// Pesan sekali tampil (snackbar); dihapus lewat [LanggananCubit.pesanDibaca].
  final String? pesan;

  bool get tersedia => paket.isNotEmpty;

  LanggananState copyWith({
    bool? memuat,
    List<PaketPlus>? paket,
    BasePlan? pilihan,
    bool? proses,
    bool? plus,
    String? pesan,
    bool hapusPesan = false,
  }) =>
      LanggananState(
        memuat: memuat ?? this.memuat,
        paket: paket ?? this.paket,
        pilihan: pilihan ?? this.pilihan,
        proses: proses ?? this.proses,
        plus: plus ?? this.plus,
        pesan: hapusPesan ? null : (pesan ?? this.pesan),
      );

  @override
  List<Object?> get props => [memuat, paket, pilihan, proses, plus, pesan];
}

class LanggananCubit extends Cubit<LanggananState> {
  LanggananCubit(this._layanan) : super(LanggananState(plus: _layanan.plusAktif)) {
    _sub = _layanan.statusPlus.listen((aktif) => emit(state.copyWith(plus: aktif)));
  }

  final LayananLangganan _layanan;
  StreamSubscription<bool>? _sub;

  Future<void> muat() async {
    emit(state.copyWith(memuat: true));
    var paket = const <PaketPlus>[];
    try {
      paket = await _layanan.muatProduk();
    } catch (_) {
      // Dianggap belum tersedia.
    }
    if (isClosed) return;
    emit(state.copyWith(memuat: false, paket: paket, plus: _layanan.plusAktif));
  }

  void pilih(BasePlan plan) => emit(state.copyWith(pilihan: plan));

  Future<void> beli() async {
    if (state.proses || state.plus || !state.tersedia) return;
    emit(state.copyWith(proses: true, hapusPesan: true));
    HasilBeli hasil;
    try {
      hasil = await _layanan.beli(state.pilihan);
    } catch (_) {
      hasil = HasilBeli.gagal;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        proses: false,
        plus: _layanan.plusAktif,
        pesan: switch (hasil) {
          HasilBeli.berhasil => 'JeliLabel Plus aktif. Terima kasih!',
          HasilBeli.tertunda => 'Pembayaran masih diproses Google Play.',
          HasilBeli.gagal => 'Pembelian belum berhasil. Coba lagi nanti.',
          HasilBeli.batal => null,
        },
      ),
    );
  }

  Future<void> pulihkan() async {
    if (state.proses) return;
    emit(state.copyWith(proses: true, hapusPesan: true));
    String pesan;
    try {
      final aktif = await _layanan.pulihkan();
      pesan = aktif ? 'Pembelian dipulihkan. JeliLabel Plus aktif.' : 'Tidak ada langganan Plus yang ditemukan.';
    } catch (_) {
      pesan = 'Belum bisa memeriksa pembelian. Coba lagi nanti.';
    }
    if (isClosed) return;
    emit(state.copyWith(proses: false, plus: _layanan.plusAktif, pesan: pesan));
  }

  void pesanDibaca() => emit(state.copyWith(hapusPesan: true));

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
