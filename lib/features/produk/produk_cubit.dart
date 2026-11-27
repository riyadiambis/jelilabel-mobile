import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../asupan/data/asupan_repository.dart';

class ProdukState extends Equatable {
  const ProdukState({
    this.semua = const [],
    this.urutan = UrutanProduk.sering,
    this.kueri = '',
    this.memuat = false,
    this.galat,
  });

  final List<ProdukRingkas> semua;
  final UrutanProduk urutan;
  final String kueri;
  final bool memuat;
  final String? galat;

  List<ProdukRingkas> get tampil {
    final q = kueri.trim().toLowerCase();
    if (q.isEmpty) return semua;
    return [
      for (final p in semua)
        if (p.nama.toLowerCase().contains(q)) p,
    ];
  }

  ProdukState copyWith({
    List<ProdukRingkas>? semua,
    UrutanProduk? urutan,
    String? kueri,
    bool? memuat,
    String? galat,
    bool hapusGalat = false,
  }) =>
      ProdukState(
        semua: semua ?? this.semua,
        urutan: urutan ?? this.urutan,
        kueri: kueri ?? this.kueri,
        memuat: memuat ?? this.memuat,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [semua, urutan, kueri, memuat, galat];
}

/// Mengelola daftar produk yang pernah dicatat untuk layar Produk saya (F6).
class ProdukCubit extends Cubit<ProdukState> {
  ProdukCubit(this._repo) : super(const ProdukState());

  final AsupanRepository _repo;

  Future<void> muat({UrutanProduk? urutan}) async {
    final targetUrutan = urutan ?? state.urutan;
    emit(state.copyWith(urutan: targetUrutan, memuat: true, hapusGalat: true));
    try {
      final daftar = await _repo.daftarProduk(urutan: targetUrutan);
      if (isClosed) return;
      emit(state.copyWith(semua: daftar, memuat: false));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuat: false, galat: 'Gagal memuat daftar produk.'));
    }
  }

  Future<void> pilihUrutan(UrutanProduk urutan) => muat(urutan: urutan);

  void ubahKueri(String kueri) => emit(state.copyWith(kueri: kueri));

  Future<bool> tautkanBarcode(int produkId, String barcode) async {
    try {
      await _repo.tautkanBarcode(produkId, barcode);
      if (isClosed) return true;
      await muat();
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal menautkan barcode.'));
      return false;
    }
  }
}
