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
    this.batas = BatasHarian.kemenkes,
  });

  factory DataKartuBagikan.dariRiwayat(
    BarisRiwayat b, {
    BatasHarian batas = BatasHarian.kemenkes,
  }) {
    final porsiTeks = b.jumlahSajian == 0.5 ? '½' : angka(b.jumlahSajian);
    return DataKartuBagikan(
      namaProduk: b.nama,
      labelPorsi: '$porsiTeks sajian',
      gulaG: b.gulaG,
      natriumMg: b.natriumMg,
      lemakTotalG: b.lemakTotalG,
      batas: batas,
    );
  }

  factory DataKartuBagikan.dariProduk(
    ProdukRingkas p, {
    BatasHarian batas = BatasHarian.kemenkes,
  }) =>
      DataKartuBagikan(
        namaProduk: p.nama,
        labelPorsi: '1 sajian',
        gulaG: p.gulaG,
        natriumMg: p.natriumMg,
        lemakTotalG: p.lemakTotalG,
        batas: batas,
      );

  final String namaProduk;
  final String labelPorsi;
  final double? gulaG;
  final double? natriumMg;
  final double? lemakTotalG;
  final BatasHarian batas;

  /// Hitung teks angka sendok, satuan, jumlah ikon, dan teks persen batas aktif.
  /// Prioritas: gula (sdm gula), fallback natrium (sdt garam), lalu lemak (sdm minyak).
  InfoKartuBagikan get info => infoDenganBatas(batas);

  InfoKartuBagikan infoDenganBatas([BatasHarian? batasAktif]) {
    final b = batasAktif ?? batas;
    if (gulaG != null) {
      final sendok = sendokGula(gulaG!);
      final persen = (persenJatah(gulaG!, b.gulaG)! * 100).round();
      final labelBatas = b.gulaBerbedaDariKemenkes
          ? 'batas gula harian (${angka(b.gulaG)} g)'
          : 'batas gula harian Kemenkes (${angka(b.gulaG)} g)';
      return InfoKartuBagikan(
        teksAngka: teksSendok(sendok),
        satuanSendok: 'sendok makan gula',
        jumlahSendok: sendok,
        teksPersen: '$persen% dari $labelBatas',
      );
    }
    if (natriumMg != null) {
      final sendok = sendokGaram(natriumMg!);
      final persen = (persenJatah(natriumMg!, b.natriumMg)! * 100).round();
      final labelBatas = b.natriumBerbedaDariKemenkes
          ? 'batas natrium harian (${angka(b.natriumMg)} mg)'
          : 'batas natrium harian Kemenkes (${angka(b.natriumMg)} mg)';
      return InfoKartuBagikan(
        teksAngka: teksSendok(sendok),
        satuanSendok: 'sendok teh garam',
        jumlahSendok: sendok,
        teksPersen: '$persen% dari $labelBatas',
      );
    }
    if (lemakTotalG != null) {
      final sendok = sendokMinyak(lemakTotalG!);
      final persen = (persenJatah(lemakTotalG!, b.lemakG)! * 100).round();
      final labelBatas = b.lemakBerbedaDariKemenkes
          ? 'batas lemak harian (${angka(b.lemakG)} g)'
          : 'batas lemak harian Kemenkes (${angka(b.lemakG)} g)';
      return InfoKartuBagikan(
        teksAngka: teksSendok(sendok),
        satuanSendok: 'sendok makan minyak',
        jumlahSendok: sendok,
        teksPersen: '$persen% dari $labelBatas',
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
  List<Object?> get props => [namaProduk, labelPorsi, gulaG, natriumMg, lemakTotalG, batas];
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
