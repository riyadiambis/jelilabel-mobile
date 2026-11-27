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

/// Profil singkat pengguna yang tersimpan lokal untuk menghitung batas harian.
class ProfilPengguna extends Equatable {
  const ProfilPengguna({
    this.umur,
    this.jenisKelamin,
    this.fokus,
    this.batasSendiriGulaG,
    this.batasSendiriNatriumMg,
    this.batasSendiriLemakG,
  });

  static const kosong = ProfilPengguna();

  final KelompokUmur? umur;
  final JenisKelamin? jenisKelamin;
  final FokusZat? fokus;
  final double? batasSendiriGulaG;
  final double? batasSendiriNatriumMg;
  final double? batasSendiriLemakG;

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
        umur,
        jenisKelamin,
        fokus,
        batasSendiriGulaG,
        batasSendiriNatriumMg,
        batasSendiriLemakG,
      ];
}
