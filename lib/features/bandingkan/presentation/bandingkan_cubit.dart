import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../asupan/data/asupan_repository.dart';

class BandingkanState extends Equatable {
  const BandingkanState({
    this.daftarProduk = const [],
    this.produkA,
    this.produkB,
    this.memuat = false,
    this.galat,
  });

  final List<ProdukRingkas> daftarProduk;
  final ProdukRingkas? produkA;
  final ProdukRingkas? produkB;
  final bool memuat;
  final String? galat;

  BandingkanState copyWith({
    List<ProdukRingkas>? daftarProduk,
    ProdukRingkas? produkA,
    ProdukRingkas? produkB,
    bool? memuat,
    String? galat,
    bool hapusGalat = false,
  }) =>
      BandingkanState(
        daftarProduk: daftarProduk ?? this.daftarProduk,
        produkA: produkA ?? this.produkA,
        produkB: produkB ?? this.produkB,
        memuat: memuat ?? this.memuat,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [daftarProduk, produkA, produkB, memuat, galat];
}

class BandingkanCubit extends Cubit<BandingkanState> {
  BandingkanCubit(this._repo) : super(const BandingkanState());

  final AsupanRepository _repo;

  Future<void> muat({ProdukRingkas? awalA, ProdukRingkas? awalB}) async {
    emit(
      state.copyWith(
        memuat: true,
        hapusGalat: true,
        produkA: awalA ?? state.produkA,
        produkB: awalB ?? state.produkB,
      ),
    );
    try {
      final daftar = await _repo.daftarProduk(urutan: UrutanProduk.sering);
      if (isClosed) return;
      emit(state.copyWith(daftarProduk: daftar, memuat: false));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuat: false, galat: 'Gagal memuat daftar produk.'));
    }
  }

  void pilihA(ProdukRingkas produk) => emit(state.copyWith(produkA: produk));

  void pilihB(ProdukRingkas produk) => emit(state.copyWith(produkB: produk));
}
