import 'package:equatable/equatable.dart';

import '../../core/ambang.dart';
import '../asupan/data/asupan_repository.dart';

/// Data sumber untuk kartu bagikan "setara sendok".
class DataKartuBagikan extends Equatable {
  const DataKartuBagikan({
    required this.namaProduk,
    required this.labelPorsi,
    this.gulaG,
    this.natriumMg,
    this.lemakTotalG,
  });

  factory DataKartuBagikan.dariRiwayat(BarisRiwayat b) {
    final porsiTeks = b.jumlahSajian == 0.5 ? '½' : angka(b.jumlahSajian);
    return DataKartuBagikan(
      namaProduk: b.nama,
      labelPorsi: '$porsiTeks sajian',
      gulaG: b.gulaG,
      natriumMg: b.natriumMg,
      lemakTotalG: b.lemakTotalG,
    );
  }

  factory DataKartuBagikan.dariProduk(ProdukRingkas p) => DataKartuBagikan(
        namaProduk: p.nama,
        labelPorsi: '1 sajian',
        gulaG: p.gulaG,
        natriumMg: p.natriumMg,
        lemakTotalG: p.lemakTotalG,
      );

  final String namaProduk;
  final String labelPorsi;
  final double? gulaG;
  final double? natriumMg;
  final double? lemakTotalG;

  /// Hitung teks angka sendok, satuan, jumlah ikon, dan teks persen batas Kemenkes.
  /// Prioritas: gula (sdm gula), fallback natrium (sdt garam), lalu lemak (sdm minyak).
  InfoKartuBagikan get info {
    if (gulaG != null) {
      final sendok = sendokGula(gulaG!);
      final persen = (persenJatah(gulaG!, batasGulaHarianG)! * 100).round();
      return InfoKartuBagikan(
        teksAngka: teksSendok(sendok),
        satuanSendok: 'sendok makan gula',
        jumlahSendok: sendok,
        teksPersen: '$persen% dari batas gula harian Kemenkes (${angka(batasGulaHarianG)} g)',
      );
    }
    if (natriumMg != null) {
      final sendok = sendokGaram(natriumMg!);
      final persen = (persenJatah(natriumMg!, batasNatriumHarianMg)! * 100).round();
      return InfoKartuBagikan(
        teksAngka: teksSendok(sendok),
        satuanSendok: 'sendok teh garam',
        jumlahSendok: sendok,
        teksPersen: '$persen% dari batas natrium harian Kemenkes (${angka(batasNatriumHarianMg)} mg)',
      );
    }
    if (lemakTotalG != null) {
      final sendok = sendokMinyak(lemakTotalG!);
      final persen = (persenJatah(lemakTotalG!, batasLemakHarianG)! * 100).round();
      return InfoKartuBagikan(
        teksAngka: teksSendok(sendok),
        satuanSendok: 'sendok makan minyak',
        jumlahSendok: sendok,
        teksPersen: '$persen% dari batas lemak harian Kemenkes (${angka(batasLemakHarianG)} g)',
      );
    }
    return const InfoKartuBagikan(
      teksAngka: '-',
      satuanSendok: 'data gizi belum diisi',
      jumlahSendok: 0,
      teksPersen: 'Tidak ada data gula, natrium, atau lemak',
    );
  }

  @override
  List<Object?> get props => [namaProduk, labelPorsi, gulaG, natriumMg, lemakTotalG];
}

class InfoKartuBagikan extends Equatable {
  const InfoKartuBagikan({
    required this.teksAngka,
    required this.satuanSendok,
    required this.jumlahSendok,
    required this.teksPersen,
  });

  final String teksAngka;
  final String satuanSendok;
  final double jumlahSendok;
  final String teksPersen;

  @override
  List<Object?> get props => [teksAngka, satuanSendok, jumlahSendok, teksPersen];
}
