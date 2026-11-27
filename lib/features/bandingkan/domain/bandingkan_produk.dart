import 'package:equatable/equatable.dart';

import '../../../core/ambang.dart';
import '../../../core/nutri_level.dart';
import '../../asupan/data/asupan_repository.dart';

enum PihakRingan { a, b }

class BarisBandingkan extends Equatable {
  const BarisBandingkan({
    required this.nama,
    required this.nilaiA,
    required this.nilaiB,
    this.persenA,
    this.persenB,
    this.lebihRingan,
  });

  final String nama;
  final String nilaiA;
  final String nilaiB;
  final String? persenA;
  final String? persenB;
  final PihakRingan? lebihRingan;

  @override
  List<Object?> get props => [nama, nilaiA, nilaiB, persenA, persenB, lebihRingan];
}

class HasilBandingkan extends Equatable {
  const HasilBandingkan({
    required this.a,
    required this.b,
    required this.fokusDipakai,
    required this.pilihanLebihRingan,
    required this.kalimatRingkas,
    required this.takaranBerbeda,
    required this.judulTakaran,
    required this.baris,
    this.nutriLevelA,
    this.nutriLevelB,
  });

  final ProdukRingkas a;
  final ProdukRingkas b;
  final FokusZat fokusDipakai;
  final PihakRingan? pilihanLebihRingan;
  final String kalimatRingkas;
  final bool takaranBerbeda;
  final String judulTakaran;
  final List<BarisBandingkan> baris;
  final HasilNutriLevel? nutriLevelA;
  final HasilNutriLevel? nutriLevelB;

  @override
  List<Object?> get props => [
        a,
        b,
        fokusDipakai,
        pilihanLebihRingan,
        kalimatRingkas,
        takaranBerbeda,
        judulTakaran,
        baris,
        nutriLevelA,
        nutriLevelB,
      ];
}

bool apakahTakaranBerbeda(ProdukRingkas a, ProdukRingkas b) {
  if (a.takaranSatuan != b.takaranSatuan) return true;
  if (a.takaranJumlah == null || b.takaranJumlah == null || a.takaranSatuan == null) return true;
  return (a.takaranJumlah! - b.takaranJumlah!).abs() > 1e-6;
}

/// Membandingkan dua produk per sajian menggunakan [batas] aktif dan zat [fokus] (default gula).
HasilBandingkan bandingkanProduk(
  ProdukRingkas a,
  ProdukRingkas b, {
  BatasHarian batas = BatasHarian.kemenkes,
  FokusZat? fokus,
}) {
  final fokusAktif = fokus ?? FokusZat.gula;
  final takaranBeda = apakahTakaranBerbeda(a, b);
  final judulTakaran = takaranBeda ? 'Per sajian' : 'Per ${angka(a.takaranJumlah!)} ${a.takaranSatuan!}';

  final baris = [
    _buatBaris('Gula', 'g', a.gulaG, b.gulaG, batas.gulaG),
    _buatBaris('Natrium', 'mg', a.natriumMg, b.natriumMg, batas.natriumMg),
    _buatBaris('Lemak', 'g', a.lemakTotalG, b.lemakTotalG, batas.lemakG),
  ];

  final (valA, valB, batasFokus, namaKecil, namaKapital, satuan) = switch (fokusAktif) {
    FokusZat.gula => (a.gulaG, b.gulaG, batas.gulaG, 'gula', 'Gula', 'g'),
    FokusZat.natrium => (a.natriumMg, b.natriumMg, batas.natriumMg, 'natrium', 'Natrium', 'mg'),
    FokusZat.lemak => (a.lemakTotalG, b.lemakTotalG, batas.lemakG, 'lemak', 'Lemak', 'g'),
  };

  final PihakRingan? ringan;
  final String kalimat;
  if (valA == null || valB == null) {
    ringan = null;
    kalimat = 'Data $namaKecil salah satu produk belum diisi.';
  } else if ((valA - valB).abs() <= 1e-6) {
    ringan = null;
    kalimat = '$namaKapital keduanya sama.';
  } else {
    final bLebihKecil = valB < valA;
    ringan = bLebihKecil ? PihakRingan.b : PihakRingan.a;
    final pihak = bLebihKecil ? 'B' : 'A';
    final selisih = (valA - valB).abs();
    final persen = ((selisih / batasFokus) * 100).round();
    kalimat = '$pihak lebih ringan ${angka(selisih)} $satuan $namaKecil. '
        'Itu $persen% dari jatah $namaKecil harianmu.';
  }

  return HasilBandingkan(
    a: a,
    b: b,
    fokusDipakai: fokusAktif,
    pilihanLebihRingan: ringan,
    kalimatRingkas: kalimat,
    takaranBerbeda: takaranBeda,
    judulTakaran: judulTakaran,
    baris: baris,
    nutriLevelA: perkiraanNutriLevel(
      takaranJumlah: a.takaranJumlah,
      takaranSatuan: a.takaranSatuan,
      gulaG: a.gulaG,
      laktosaG: a.laktosaG,
      natriumMg: a.natriumMg,
      lemakJenuhG: a.lemakJenuhG,
    ),
    nutriLevelB: perkiraanNutriLevel(
      takaranJumlah: b.takaranJumlah,
      takaranSatuan: b.takaranSatuan,
      gulaG: b.gulaG,
      laktosaG: b.laktosaG,
      natriumMg: b.natriumMg,
      lemakJenuhG: b.lemakJenuhG,
    ),
  );
}

BarisBandingkan _buatBaris(
  String nama,
  String satuan,
  double? valA,
  double? valB,
  double batasHarian,
) {
  final pA = persenJatah(valA, batasHarian);
  final pB = persenJatah(valB, batasHarian);
  PihakRingan? ringan;
  if (valA != null && valB != null && (valA - valB).abs() > 1e-6) {
    ringan = valB < valA ? PihakRingan.b : PihakRingan.a;
  }
  return BarisBandingkan(
    nama: nama,
    nilaiA: valA == null ? '-' : '${angka(valA)} $satuan',
    nilaiB: valB == null ? '-' : '${angka(valB)} $satuan',
    persenA: pA == null ? null : '${(pA * 100).round()}% jatah',
    persenB: pB == null ? null : '${(pB * 100).round()}% jatah',
    lebihRingan: ringan,
  );
}
