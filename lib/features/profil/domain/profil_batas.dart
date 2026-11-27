import 'package:equatable/equatable.dart';

import '../../../core/ambang.dart';

export '../../../core/ambang.dart'
    show
        BatasHarian,
        FokusZat,
        JenisKelamin,
        KelompokUmur,
        SumberBatas,
        akgEnergiKkal,
        hitungBatasHarian;

const maksProfilKeluarga = 5;
const maksPanjangNamaProfil = 20;

/// Profil anggota keluarga yang tersimpan lokal untuk batas harian dan catatan terpisah.
class ProfilPengguna extends Equatable {
  const ProfilPengguna({
    this.id,
    this.nama = 'Saya',
    this.umur,
    this.jenisKelamin,
    this.fokus,
    this.batasSendiriGulaG,
    this.batasSendiriNatriumMg,
    this.batasSendiriLemakG,
    this.dibuatPada,
  });

  static const kosong = ProfilPengguna();

  final int? id;
  final String nama;
  final KelompokUmur? umur;
  final JenisKelamin? jenisKelamin;
  final FokusZat? fokus;
  final double? batasSendiriGulaG;
  final double? batasSendiriNatriumMg;
  final double? batasSendiriLemakG;
  final int? dibuatPada;

  String get hurufAwal {
    final bersih = nama.trim();
    if (bersih.isEmpty) return 'S';
    return bersih.substring(0, 1).toUpperCase();
  }

  String get keteranganSingkat {
    final fokusTeks = 'fokus ${(fokus ?? FokusZat.gula).label.toLowerCase()}';
    if (umur != null) return '${umur!.kode} tahun · $fokusTeks';
    return 'Batas ${batasHarian.sumber.label} · $fokusTeks';
  }

  bool get punyaBatasSendiri =>
      (batasSendiriGulaG != null && batasSendiriGulaG! > 0) ||
      (batasSendiriNatriumMg != null && batasSendiriNatriumMg! > 0) ||
      (batasSendiriLemakG != null && batasSendiriLemakG! > 0);

  BatasHarian get batasHarian => hitungBatasHarian(
        umur: umur,
        jenisKelamin: jenisKelamin,
        batasSendiriGulaG: batasSendiriGulaG,
        batasSendiriNatriumMg: batasSendiriNatriumMg,
        batasSendiriLemakG: batasSendiriLemakG,
      );

  @override
  List<Object?> get props => [
        id,
        nama,
        umur,
        jenisKelamin,
        fokus,
        batasSendiriGulaG,
        batasSendiriNatriumMg,
        batasSendiriLemakG,
        dibuatPada,
      ];
}
