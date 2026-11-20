/// Angka dan aturan dari docs/AMBANG-STATUS.md (masih usulan K-7).
library;

const batasGulaHarianG = 50.0;
const batasNatriumHarianMg = 2000.0;

enum StatusGizi { aman, waspada, tinggi, tidakDiketahui }

enum StatusHarian { aman, hampirBatas, lewatBatas }

/// Bagian dari batas harian, 0.24 = 24%. Null bila nilai tidak diketahui.
double? persenJatah(double? nilai, double batasHarian) => nilai == null ? null : nilai / batasHarian;

StatusGizi statusZat(double? nilai, double batasHarian) {
  final p = persenJatah(nilai, batasHarian);
  if (p == null) return StatusGizi.tidakDiketahui;
  if (p < 0.10) return StatusGizi.aman;
  if (p <= 0.25) return StatusGizi.waspada;
  return StatusGizi.tinggi;
}

/// Status produk = status terburuk dari gula dan natrium. Nilai tidak diketahui tidak dianggap 0.
StatusGizi statusPorsi(double? gulaG, double? natriumMg) {
  final semua = [statusZat(gulaG, batasGulaHarianG), statusZat(natriumMg, batasNatriumHarianMg)]
      .where((s) => s != StatusGizi.tidakDiketahui)
      .toList();
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
  final bulat = x.roundToDouble() == x;
  final t = bulat ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
  return t.replaceAll('.', ',');
}
