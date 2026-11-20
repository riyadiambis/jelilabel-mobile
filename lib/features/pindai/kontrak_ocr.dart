import 'package:equatable/equatable.dart';

import '../asupan/data/asupan_repository.dart';

/// Kode galat resmi kontrak Cloud Functions OCR (docs/AI-CONTRACT.md v1.1).
enum GalatPindai {
  unauthenticated,
  resourceExhausted,
  invalidArgument,
  deadlineExceeded,
  internal,
  tidakTerbaca,
  dibatalkan,
}

GalatPindai galatPindaiDariKode(String kode) => switch (kode) {
      'unauthenticated' => GalatPindai.unauthenticated,
      'resource-exhausted' => GalatPindai.resourceExhausted,
      'invalid-argument' => GalatPindai.invalidArgument,
      'deadline-exceeded' => GalatPindai.deadlineExceeded,
      'internal' => GalatPindai.internal,
      _ => GalatPindai.internal,
    };

String pesanGalatPindai(GalatPindai galat) => switch (galat) {
      GalatPindai.unauthenticated => 'Coba lagi',
      GalatPindai.resourceExhausted => 'Kuota pindai minggu ini habis',
      GalatPindai.invalidArgument || GalatPindai.tidakTerbaca => 'Label tidak terbaca',
      GalatPindai.deadlineExceeded => 'Coba lagi',
      GalatPindai.internal => 'Coba lagi nanti',
      GalatPindai.dibatalkan => 'Pindai dibatalkan',
    };

class StatusKuotaServer extends Equatable {
  const StatusKuotaServer({
    required this.dasar,
    required this.bonusIklan,
    required this.terpakai,
    required this.sisa,
    required this.plafon,
  });

  final int dasar;
  final int bonusIklan;
  final int terpakai;
  final int sisa;
  final int plafon;

  factory StatusKuotaServer.fromJson(Map<String, dynamic> json) => StatusKuotaServer(
        dasar: (json['dasar'] as num?)?.toInt() ?? 5,
        bonusIklan: (json['bonusIklan'] as num?)?.toInt() ?? 0,
        terpakai: (json['terpakai'] as num?)?.toInt() ?? 0,
        sisa: (json['sisa'] as num?)?.toInt() ?? 0,
        plafon: (json['plafon'] as num?)?.toInt() ?? 15,
      );

  @override
  List<Object?> get props => [dasar, bonusIklan, terpakai, sisa, plafon];
}

class ResponsOcr extends Equatable {
  const ResponsOcr({required this.draf, this.kuota});

  final DrafProduk? draf;
  final StatusKuotaServer? kuota;

  bool get terbaca => draf != null;

  @override
  List<Object?> get props => [draf, kuota];
}

double? _bacaAngka(Object? nilai) => nilai is num && nilai.isFinite ? nilai.toDouble() : null;

Map<String, dynamic>? _keMapString(Object? nilai) {
  if (nilai is Map<String, dynamic>) return nilai;
  if (nilai is Map) {
    return nilai.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

/// Memvalidasi objek `hasil` sesuai AI-CONTRACT.md v1.1.
/// Mengembalikan null jika `terbaca == false` atau gula dan natrium/garam sama-sama null.
DrafProduk? validasiHasilOcr(
  Map<String, dynamic> hasil, {
  String namaDefault = 'Produk dipindai',
}) {
  if (hasil['terbaca'] != true) return null;

  final perSajian = _keMapString(hasil['per_sajian']);
  if (perSajian == null) return null;

  final gula = _bacaAngka(perSajian['gula_g']);
  final natriumMentah = _bacaAngka(perSajian['natrium_mg']);
  final garam = _bacaAngka(perSajian['garam_g']);

  final double? natrium = natriumMentah ?? (garam == null ? null : garam * 400);
  if (gula == null && natrium == null) return null;

  final cekLagiGula = gula != null && (gula < 0 || gula > 100);
  final cekLagiNatrium = natrium != null && (natrium < 0 || natrium > 5000);

  final takaran = _keMapString(hasil['takaran_saji']);
  double? takaranJumlah;
  String? takaranSatuan;
  if (takaran != null) {
    takaranJumlah = _bacaAngka(takaran['jumlah']);
    final satuan = takaran['satuan'];
    if (satuan is String && (satuan == 'g' || satuan == 'ml')) {
      takaranSatuan = satuan;
    }
  }

  return DrafProduk(
    nama: namaDefault,
    gulaG: gula,
    natriumMg: natrium,
    takaranJumlah: takaranJumlah,
    takaranSatuan: takaranSatuan,
    sajianPerKemasan: _bacaAngka(hasil['sajian_per_kemasan']),
    cekLagiGula: cekLagiGula,
    cekLagiNatrium: cekLagiNatrium,
  );
}

/// Mem-parse respons penuh Cloud Functions (`{ hasil: ..., kuota: ... }`).
ResponsOcr parseResponsOcr(
  Map<String, dynamic> json, {
  String namaDefault = 'Produk dipindai',
}) {
  final kuotaRaw = _keMapString(json['kuota']);
  final kuota = kuotaRaw != null ? StatusKuotaServer.fromJson(kuotaRaw) : null;

  final hasilRaw = _keMapString(json['hasil']);
  DrafProduk? draf;
  if (hasilRaw != null) {
    draf = validasiHasilOcr(hasilRaw, namaDefault: namaDefault);
  } else if (json.containsKey('terbaca')) {
    draf = validasiHasilOcr(json, namaDefault: namaDefault);
  }

  return ResponsOcr(draf: draf, kuota: kuota);
}
