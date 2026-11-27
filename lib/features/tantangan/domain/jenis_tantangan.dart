import 'package:equatable/equatable.dart';

import '../../../core/ambang.dart';
import '../../asupan/data/asupan_repository.dart' show tanggalLokal;

/// Panjang jendela setiap tantangan dalam hari kalender lokal.
const jendelaTantanganHari = 7;

enum StatusTantangan {
  berjalan('berjalan'),
  selesai('selesai'),
  berakhir('berakhir');

  const StatusTantangan(this.kode);
  final String kode;

  static StatusTantangan dariKode(String kode) => StatusTantangan.values.firstWhere(
        (s) => s.kode == kode,
        orElse: () => StatusTantangan.berakhir,
      );
}

enum StatusHariTantangan { berhasil, belum, mendatang }

/// Konstanta jenis tantangan resmi sesuai ISSUE-16 dan ambang Kemenkes di ambang.dart.
enum JenisTantangan {
  gula5(
    kode: 'gula_5',
    judul: '5 hari gula di bawah batas',
    keterangan: '5 hari ada catatan dengan total gula maksimal 50 g dalam 7 hari',
    targetHari: 5,
    batasHarian: batasGulaHarianG,
  ),
  natrium5(
    kode: 'natrium_5',
    judul: '5 hari natrium di bawah batas',
    keterangan: '5 hari ada catatan dengan total natrium maksimal 2000 mg dalam 7 hari',
    targetHari: 5,
    batasHarian: batasNatriumHarianMg,
  ),
  lemak5(
    kode: 'lemak_5',
    judul: '5 hari lemak di bawah batas',
    keterangan: '5 hari ada catatan dengan total lemak maksimal 67 g dalam 7 hari',
    targetHari: 5,
    batasHarian: batasLemakHarianG,
  ),
  catat7(
    kode: 'catat_7',
    judul: 'Catat jajanan 7 hari',
    keterangan: 'Catat minimal 1 produk setiap hari selama 7 hari berturut-turut',
    targetHari: 7,
    batasHarian: null,
  );

  const JenisTantangan({
    required this.kode,
    required this.judul,
    required this.keterangan,
    required this.targetHari,
    required this.batasHarian,
  });

  final String kode;
  final String judul;
  final String keterangan;
  final int targetHari;
  final double? batasHarian;

  static JenisTantangan? dariKode(String kode) {
    for (final j in JenisTantangan.values) {
      if (j.kode == kode) return j;
    }
    return null;
  }
}

/// Agregat konsumsi satu hari kalender untuk menghitung syarat tantangan.
class RingkasanHariTantangan extends Equatable {
  const RingkasanHariTantangan({
    required this.jumlahCatatan,
    required this.adaGula,
    required this.totalGula,
    required this.adaNatrium,
    required this.totalNatrium,
    required this.adaLemak,
    required this.totalLemak,
  });

  final int jumlahCatatan;
  final int adaGula;
  final double totalGula;
  final int adaNatrium;
  final double totalNatrium;
  final int adaLemak;
  final double totalLemak;

  @override
  List<Object?> get props => [
        jumlahCatatan,
        adaGula,
        totalGula,
        adaNatrium,
        totalNatrium,
        adaLemak,
        totalLemak,
      ];
}

class HariTantangan extends Equatable {
  const HariTantangan({required this.tanggal, required this.status});

  final DateTime tanggal;
  final StatusHariTantangan status;

  @override
  List<Object?> get props => [tanggal, status];
}

class KemajuanTantangan extends Equatable {
  const KemajuanTantangan({
    required this.id,
    required this.jenis,
    required this.mulai,
    required this.status,
    required this.selesaiPada,
    required this.tujuhHari,
    required this.jumlahBerhasil,
    required this.sisaHari,
    required this.jendelaLewat,
  });

  final int id;
  final JenisTantangan jenis;
  final DateTime mulai;
  final StatusTantangan status;
  final int? selesaiPada;
  final List<HariTantangan> tujuhHari;
  final int jumlahBerhasil;
  final int sisaHari;
  final bool jendelaLewat;

  int get target => jenis.targetHari;

  int get terpenuhi => jumlahBerhasil > target ? target : jumlahBerhasil;

  bool get tercapai => jumlahBerhasil >= target;

  KemajuanTantangan denganStatus(StatusTantangan statusBaru, {int? selesaiPadaBaru}) => KemajuanTantangan(
        id: id,
        jenis: jenis,
        mulai: mulai,
        status: statusBaru,
        selesaiPada: selesaiPadaBaru ?? selesaiPada,
        tujuhHari: tujuhHari,
        jumlahBerhasil: jumlahBerhasil,
        sisaHari: sisaHari,
        jendelaLewat: jendelaLewat,
      );

  @override
  List<Object?> get props => [
        id,
        jenis,
        mulai,
        status,
        selesaiPada,
        tujuhHari,
        jumlahBerhasil,
        sisaHari,
        jendelaLewat,
      ];
}

class LencanaTantangan extends Equatable {
  const LencanaTantangan({
    required this.id,
    required this.jenis,
    required this.selesaiPada,
  });

  final int id;
  final JenisTantangan jenis;
  final int selesaiPada;

  DateTime get tanggalSelesai => DateTime.fromMillisecondsSinceEpoch(selesaiPada);

  @override
  List<Object?> get props => [id, jenis, selesaiPada];
}

/// Menghitung kemajuan tantangan dalam jendela 7 hari sejak [mulai] pada tanggal lokal [hariIni].
KemajuanTantangan hitungKemajuanTantangan({
  required int id,
  required JenisTantangan jenis,
  required DateTime mulai,
  required StatusTantangan status,
  required int? selesaiPada,
  required DateTime hariIni,
  required Map<String, RingkasanHariTantangan> harian,
}) {
  final awal = DateTime(mulai.year, mulai.month, mulai.day);
  final kini = DateTime(hariIni.year, hariIni.month, hariIni.day);
  final akhir = DateTime(awal.year, awal.month, awal.day + (jendelaTantanganHari - 1));

  final awalUtc = DateTime.utc(awal.year, awal.month, awal.day);
  final kiniUtc = DateTime.utc(kini.year, kini.month, kini.day);
  final akhirUtc = DateTime.utc(akhir.year, akhir.month, akhir.day);

  final daftarHari = <HariTantangan>[];
  var berhasil = 0;

  for (var i = 0; i < jendelaTantanganHari; i++) {
    final tgl = DateTime(awal.year, awal.month, awal.day + i);
    final tglUtc = awalUtc.add(Duration(days: i));
    if (tglUtc.isAfter(kiniUtc)) {
      daftarHari.add(HariTantangan(tanggal: tgl, status: StatusHariTantangan.mendatang));
      continue;
    }
    final data = harian[tanggalLokal(tgl)];
    final lulusHari = data != null && _hariMemenuhiSyarat(jenis, data);
    if (lulusHari) berhasil++;
    daftarHari.add(
      HariTantangan(
        tanggal: tgl,
        status: lulusHari ? StatusHariTantangan.berhasil : StatusHariTantangan.belum,
      ),
    );
  }

  final sisaHari = akhirUtc.difference(kiniUtc).inDays.clamp(0, jendelaTantanganHari - 1);
  final jendelaLewat = kiniUtc.isAfter(akhirUtc);

  return KemajuanTantangan(
    id: id,
    jenis: jenis,
    mulai: awal,
    status: status,
    selesaiPada: selesaiPada,
    tujuhHari: daftarHari,
    jumlahBerhasil: berhasil,
    sisaHari: sisaHari,
    jendelaLewat: jendelaLewat,
  );
}

bool _hariMemenuhiSyarat(JenisTantangan jenis, RingkasanHariTantangan data) {
  if (data.jumlahCatatan <= 0) return false;
  return switch (jenis) {
    JenisTantangan.gula5 => data.adaGula > 0 && data.totalGula <= jenis.batasHarian!,
    JenisTantangan.natrium5 => data.adaNatrium > 0 && data.totalNatrium <= jenis.batasHarian!,
    JenisTantangan.lemak5 => data.adaLemak > 0 && data.totalLemak <= jenis.batasHarian!,
    JenisTantangan.catat7 => data.jumlahCatatan >= 1,
  };
}
