/// Angka dan aturan dari docs/AMBANG-STATUS.md (masih usulan K-7) dan docs/AKG-2019.md.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

const batasGulaHarianG = 50.0;
const batasNatriumHarianMg = 2000.0;
const batasLemakHarianG = 67.0;

enum StatusGizi { aman, waspada, tinggi, tidakDiketahui }

enum StatusHarian { aman, hampirBatas, lewatBatas }

/// Kelompok umur AKG Permenkes 28/2019 (usia 13 tahun ke atas).
enum KelompokUmur {
  u13_15('13-15'),
  u16_18('16-18'),
  u19_29('19-29'),
  u30_49('30-49'),
  u50_64('50-64'),
  u65_80('65-80'),
  u80Plus('80+');

  const KelompokUmur(this.kode);
  final String kode;

  static KelompokUmur? dariKode(String? kode) {
    if (kode == null) return null;
    for (final u in KelompokUmur.values) {
      if (u.kode == kode) return u;
    }
    return null;
  }
}

enum JenisKelamin {
  lakiLaki('L', 'Laki-laki'),
  perempuan('P', 'Perempuan');

  const JenisKelamin(this.kode, this.label);
  final String kode;
  final String label;

  static JenisKelamin? dariKode(String? kode) {
    if (kode == null) return null;
    for (final j in JenisKelamin.values) {
      if (j.kode == kode) return j;
    }
    return null;
  }
}

enum FokusZat {
  gula('gula', 'Gula'),
  natrium('natrium', 'Natrium'),
  lemak('lemak', 'Lemak');

  const FokusZat(this.kode, this.label);
  final String kode;
  final String label;

  static FokusZat? dariKode(String? kode) {
    if (kode == null) return null;
    for (final f in FokusZat.values) {
      if (f.kode == kode) return f;
    }
    return null;
  }
}

enum SumberBatas {
  kemenkes('Kemenkes'),
  pribadi('Pribadi'),
  dariDokter('Dari dokter');

  const SumberBatas(this.label);
  final String label;
}

/// Energi AKG (kkal/hari) disalin dari docs/AKG-2019.md (Permenkes 28/2019 Tabel 1).
const Map<KelompokUmur, ({int lakiLaki, int perempuan})> akgEnergiKkal = {
  KelompokUmur.u13_15: (lakiLaki: 2400, perempuan: 2050),
  KelompokUmur.u16_18: (lakiLaki: 2650, perempuan: 2100),
  KelompokUmur.u19_29: (lakiLaki: 2650, perempuan: 2250),
  KelompokUmur.u30_49: (lakiLaki: 2550, perempuan: 2150),
  KelompokUmur.u50_64: (lakiLaki: 2150, perempuan: 1800),
  KelompokUmur.u65_80: (lakiLaki: 1800, perempuan: 1550),
  KelompokUmur.u80Plus: (lakiLaki: 1600, perempuan: 1400),
};

/// Batas harian aktif untuk gula, natrium, dan lemak beserta sumber hitungannya.
class BatasHarian extends Equatable {
  const BatasHarian({
    this.gulaG = batasGulaHarianG,
    this.natriumMg = batasNatriumHarianMg,
    this.lemakG = batasLemakHarianG,
    this.sumber = SumberBatas.kemenkes,
  });

  static const kemenkes = BatasHarian();

  final double gulaG;
  final double natriumMg;
  final double lemakG;
  final SumberBatas sumber;

  bool get gulaBerbedaDariKemenkes => gulaG != batasGulaHarianG;
  bool get natriumBerbedaDariKemenkes => natriumMg != batasNatriumHarianMg;
  bool get lemakBerbedaDariKemenkes => lemakG != batasLemakHarianG;
  bool get berbedaDariKemenkes =>
      gulaBerbedaDariKemenkes || natriumBerbedaDariKemenkes || lemakBerbedaDariKemenkes;

  @override
  List<Object?> get props => [gulaG, natriumMg, lemakG, sumber];
}

/// Menghitung [BatasHarian] dari profil AKG dan batas sendiri opsional.
/// Gula AKG = min(50, floor(energiAKG * 0,10 / 4)). Natrium = 2000 mg, Lemak = 67 g.
BatasHarian hitungBatasHarian({
  KelompokUmur? umur,
  JenisKelamin? jenisKelamin,
  double? batasSendiriGulaG,
  double? batasSendiriNatriumMg,
  double? batasSendiriLemakG,
}) {
  var gula = batasGulaHarianG;
  final punyaAkg = umur != null && jenisKelamin != null;
  if (punyaAkg) {
    final entri = akgEnergiKkal[umur]!;
    final energi = jenisKelamin == JenisKelamin.lakiLaki ? entri.lakiLaki : entri.perempuan;
    // energi * 0,10 / 4 sama dengan energi / 40; pembagian bulat menghindari galat floating point.
    gula = math.min(50, energi ~/ 40).toDouble();
  }

  var natrium = batasNatriumHarianMg;
  var lemak = batasLemakHarianG;
  var adaBatasSendiri = false;

  if (batasSendiriGulaG != null && batasSendiriGulaG > 0) {
    gula = batasSendiriGulaG;
    adaBatasSendiri = true;
  }
  if (batasSendiriNatriumMg != null && batasSendiriNatriumMg > 0) {
    natrium = batasSendiriNatriumMg;
    adaBatasSendiri = true;
  }
  if (batasSendiriLemakG != null && batasSendiriLemakG > 0) {
    lemak = batasSendiriLemakG;
    adaBatasSendiri = true;
  }

  final sumber = adaBatasSendiri
      ? SumberBatas.dariDokter
      : (punyaAkg ? SumberBatas.pribadi : SumberBatas.kemenkes);

  return BatasHarian(
    gulaG: gula,
    natriumMg: natrium,
    lemakG: lemak,
    sumber: sumber,
  );
}

/// Bagian dari batas harian, 0.24 = 24%. Null bila nilai tidak diketahui.
double? persenJatah(double? nilai, double batasHarian) => nilai == null ? null : nilai / batasHarian;

StatusGizi statusZat(double? nilai, double batasHarian) {
  final p = persenJatah(nilai, batasHarian);
  if (p == null) return StatusGizi.tidakDiketahui;
  if (p < 0.10) return StatusGizi.aman;
  if (p <= 0.25) return StatusGizi.waspada;
  return StatusGizi.tinggi;
}

/// Status produk = status terburuk dari gula, natrium, dan lemak. Nilai tidak diketahui tidak dianggap 0.
StatusGizi statusPorsi(
  double? gulaG,
  double? natriumMg, [
  double? lemakG,
  BatasHarian batas = BatasHarian.kemenkes,
]) {
  final semua = [
    statusZat(gulaG, batas.gulaG),
    statusZat(natriumMg, batas.natriumMg),
    statusZat(lemakG, batas.lemakG),
  ].where((s) => s != StatusGizi.tidakDiketahui).toList();
  if (semua.isEmpty) return StatusGizi.tidakDiketahui;
  if (semua.contains(StatusGizi.tinggi)) return StatusGizi.tinggi;
  if (semua.contains(StatusGizi.waspada)) return StatusGizi.waspada;
  return StatusGizi.aman;
}

StatusHarian statusHarian(double total, double batasHarian) {
  final p = total / batasHarian;
  if (p < 0.75) return StatusHarian.aman;
  if (p <= 1.0) return StatusHarian.hampirBatas;
  return StatusHarian.lewatBatas;
}

/// G4: 4 sdm = 50 g gula.
double sendokGula(double gulaG) => _setengah(gulaG / 12.5);

/// G1: 1 sdt garam (5 g) setara 2000 mg natrium.
double sendokGaram(double natriumMg) => _setengah(natriumMg / 2000);

/// L5: 5 sdm minyak = 67 g lemak (1 sdm = 13,4 g).
double sendokMinyak(double lemakG) => _setengah(lemakG / 13.4);

double _setengah(double x) => (x * 2).round() / 2;

/// Teks takaran: di bawah 0,25 tampil "< ½".
String teksSendok(double nilaiMentah) {
  if (nilaiMentah < 0.25) return '< ½';
  final s = _setengah(nilaiMentah);
  if (s == 0.5) return '½';
  return angka(s);
}

/// Angka gaya Indonesia: koma desimal, tanpa ",0".
String angka(double x) {
  final r = (x * 10).round() / 10; // bulatkan dulu, agar 12,96 tampil "13", bukan "13,0"
  final t = r.roundToDouble() == r ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  return t.replaceAll('.', ',');
}
