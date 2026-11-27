import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/ambang.dart';

/// Format tanggal lokal perangkat 'YYYY-MM-DD' (bukan UTC).
String tanggalLokal(DateTime waktu) {
  final l = waktu.isUtc ? waktu.toLocal() : waktu;
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final d = l.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Format tanggal Senin lokal 'YYYY-MM-DD' untuk penanda minggu kuota.
String awalMingguLokal(DateTime waktu) {
  final l = waktu.isUtc ? waktu.toLocal() : waktu;
  final senin = DateTime(l.year, l.month, l.day - (l.weekday - DateTime.monday));
  return tanggalLokal(senin);
}

/// Hasil baca label (per sajian), masih draf sampai pengguna menekan Simpan.
class DrafProduk extends Equatable {
  const DrafProduk({
    required this.nama,
    this.gulaG,
    this.natriumMg,
    this.lemakTotalG,
    this.takaranJumlah,
    this.takaranSatuan,
    this.sajianPerKemasan,
    this.cekLagiGula = false,
    this.cekLagiNatrium = false,
    this.cekLagiLemak = false,
  });

  final String nama;
  final double? gulaG;
  final double? natriumMg;
  final double? lemakTotalG;
  final double? takaranJumlah;
  final String? takaranSatuan;
  final double? sajianPerKemasan;
  final bool cekLagiGula;
  final bool cekLagiNatrium;
  final bool cekLagiLemak;

  static const kosong = DrafProduk(nama: '');

  @override
  List<Object?> get props => [
        nama,
        gulaG,
        natriumMg,
        lemakTotalG,
        takaranJumlah,
        takaranSatuan,
        sajianPerKemasan,
        cekLagiGula,
        cekLagiNatrium,
        cekLagiLemak,
      ];
}

/// Satu baris konsumsi dengan nilai snapshot saat simpan.
class BarisRiwayat extends Equatable {
  const BarisRiwayat({
    required this.id,
    required this.produkId,
    required this.nama,
    required this.jumlahSajian,
    required this.gulaG,
    required this.natriumMg,
    this.lemakTotalG,
    required this.tanggal,
    required this.dibuatPada,
  });

  final int id;
  final int produkId;
  final String nama;
  final double jumlahSajian;
  final double? gulaG;
  final double? natriumMg;
  final double? lemakTotalG;
  final String tanggal;
  final int dibuatPada;

  DateTime get waktu => DateTime.fromMillisecondsSinceEpoch(dibuatPada);

  DateTime get tanggalLokalObjek {
    final bagian = tanggal.split('-');
    return DateTime(int.parse(bagian[0]), int.parse(bagian[1]), int.parse(bagian[2]));
  }

  StatusGizi get status => statusPorsi(gulaG, natriumMg, lemakTotalG);

  StatusGizi statusUntuk(BatasHarian batas) => statusPorsi(gulaG, natriumMg, lemakTotalG, batas);

  @override
  List<Object?> get props => [id, produkId, nama, jumlahSajian, gulaG, natriumMg, lemakTotalG, tanggal, dibuatPada];
}

/// Ringkasan asupan harian dari SQLite.
class RingkasanHari extends Equatable {
  const RingkasanHari({
    this.totalGula = 0,
    this.totalNatrium = 0,
    this.totalLemak = 0,
    this.jumlahCatatan = 0,
    this.jumlahTanpaGula = 0,
    this.jumlahTanpaNatrium = 0,
    this.jumlahTanpaLemak = 0,
  });

  final double totalGula;
  final double totalNatrium;
  final double totalLemak;
  final int jumlahCatatan;
  final int jumlahTanpaGula;
  final int jumlahTanpaNatrium;
  final int jumlahTanpaLemak;

  @override
  List<Object?> get props => [
        totalGula,
        totalNatrium,
        totalLemak,
        jumlahCatatan,
        jumlahTanpaGula,
        jumlahTanpaNatrium,
        jumlahTanpaLemak,
      ];
}

/// Ringkasan asupan mingguan (Senin-Minggu lokal) untuk layar Rapor.
class RingkasanMinggu extends Equatable {
  const RingkasanMinggu({
    required this.awalMinggu,
    required this.akhirMinggu,
    this.jumlahCatatan = 0,
    this.hariAdaCatatan = 0,
    this.hariGulaDiBawahBatas = 0,
    this.totalGula = 0,
    this.rataGula = 0,
    this.rataNatrium = 0,
    this.rataLemak = 0,
  });

  final DateTime awalMinggu;
  final DateTime akhirMinggu;
  final int jumlahCatatan;
  final int hariAdaCatatan;
  final int hariGulaDiBawahBatas;
  final double totalGula;
  final double rataGula;
  final double rataNatrium;
  final double rataLemak;

  int get hariKosong => (7 - hariAdaCatatan).clamp(0, 7);

  @override
  List<Object?> get props => [
        awalMinggu,
        akhirMinggu,
        jumlahCatatan,
        hariAdaCatatan,
        hariGulaDiBawahBatas,
        totalGula,
        rataGula,
        rataNatrium,
        rataLemak,
      ];
}

/// Produk penyumbang gula dalam satu minggu.
class PenyumbangGula extends Equatable {
  const PenyumbangGula({
    required this.nama,
    required this.totalGula,
    required this.persen,
    required this.jumlahKali,
  });

  final String nama;
  final double totalGula;
  final double persen;
  final int jumlahKali;

  @override
  List<Object?> get props => [nama, totalGula, persen, jumlahKali];
}

enum UrutanProduk { sering, terbaru }

/// Ringkasan satu produk yang pernah dicatat di tabel konsumsi.
class ProdukRingkas extends Equatable {
  const ProdukRingkas({
    required this.id,
    required this.nama,
    this.gulaG,
    this.natriumMg,
    this.lemakTotalG,
    this.takaranJumlah,
    this.takaranSatuan,
    this.sajianPerKemasan,
    required this.jumlahKali,
    required this.terakhirDicatat,
  });

  final int id;
  final String nama;
  final double? gulaG;
  final double? natriumMg;
  final double? lemakTotalG;
  final double? takaranJumlah;
  final String? takaranSatuan;
  final double? sajianPerKemasan;
  final int jumlahKali;
  final int terakhirDicatat;

  @override
  List<Object?> get props => [
        id,
        nama,
        gulaG,
        natriumMg,
        lemakTotalG,
        takaranJumlah,
        takaranSatuan,
        sajianPerKemasan,
        jumlahKali,
        terakhirDicatat,
      ];
}

/// Satu-satunya pintu akses basis data lokal untuk fitur asupan dan pengaturan.
class AsupanRepository {
  AsupanRepository(this._db);

  final Database _db;

  static const kunciPerkenalanSelesai = 'perkenalan_selesai';
  static const kunciPeringatanGulaTanggal = 'peringatan_gula_tanggal';
  static const kunciPeringatanNatriumTanggal = 'peringatan_natrium_tanggal';
  static const kunciPeringatanLemakTanggal = 'peringatan_lemak_tanggal';
  static const kunciKuotaMinggu = 'kuota_minggu';
  static const kunciKuotaTerpakai = 'kuota_terpakai';
  static const kunciKuotaBonusIklan = 'kuota_bonus_iklan';

  Future<int> simpanKonsumsi({
    required DrafProduk draf,
    required double jumlahSajian,
    required DateTime waktuLokal,
    String sumber = 'pindai',
  }) async {
    if (jumlahSajian <= 0) {
      throw ArgumentError.value(jumlahSajian, 'jumlahSajian', 'Harus lebih dari 0');
    }
    final nama = draf.nama.trim();
    if (nama.isEmpty) {
      throw ArgumentError.value(draf.nama, 'draf.nama', 'Nama produk tidak boleh kosong');
    }
    final satuan = (draf.takaranSatuan == 'g' || draf.takaranSatuan == 'ml') ? draf.takaranSatuan : null;
    final lokal = waktuLokal.isUtc ? waktuLokal.toLocal() : waktuLokal;
    final epochMs = lokal.millisecondsSinceEpoch;
    final tgl = tanggalLokal(lokal);

    return _db.transaction((txn) async {
      final produkId = await txn.insert('produk', {
        'nama': nama,
        'takaran_saji_jumlah': draf.takaranJumlah,
        'takaran_saji_satuan': satuan,
        'sajian_per_kemasan': draf.sajianPerKemasan,
        'gula_g': draf.gulaG,
        'natrium_mg': draf.natriumMg,
        'energi_kkal': null,
        'lemak_total_g': draf.lemakTotalG,
        'protein_g': null,
        'karbohidrat_g': null,
        'sumber': sumber,
        'dibuat_pada': epochMs,
      });

      return txn.insert('konsumsi', {
        'produk_id': produkId,
        'jumlah_sajian': jumlahSajian,
        'gula_g': draf.gulaG == null ? null : draf.gulaG! * jumlahSajian,
        'natrium_mg': draf.natriumMg == null ? null : draf.natriumMg! * jumlahSajian,
        'lemak_total_g': draf.lemakTotalG == null ? null : draf.lemakTotalG! * jumlahSajian,
        'tanggal': tgl,
        'dibuat_pada': epochMs,
      });
    });
  }

  Future<RingkasanHari> ringkasanHari(DateTime hari) async {
    final tgl = tanggalLokal(hari);
    final rows = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(gula_g), 0) AS total_gula,
        COALESCE(SUM(natrium_mg), 0) AS total_natrium,
        COALESCE(SUM(lemak_total_g), 0) AS total_lemak,
        COUNT(*) AS jumlah_catatan,
        COALESCE(SUM(CASE WHEN gula_g IS NULL THEN 1 ELSE 0 END), 0) AS tanpa_gula,
        COALESCE(SUM(CASE WHEN natrium_mg IS NULL THEN 1 ELSE 0 END), 0) AS tanpa_natrium,
        COALESCE(SUM(CASE WHEN lemak_total_g IS NULL THEN 1 ELSE 0 END), 0) AS tanpa_lemak
      FROM konsumsi
      WHERE tanggal = ?
      ''',
      [tgl],
    );
    final r = rows.first;
    return RingkasanHari(
      totalGula: (r['total_gula'] as num).toDouble(),
      totalNatrium: (r['total_natrium'] as num).toDouble(),
      totalLemak: (r['total_lemak'] as num).toDouble(),
      jumlahCatatan: (r['jumlah_catatan'] as num).toInt(),
      jumlahTanpaGula: (r['tanpa_gula'] as num).toInt(),
      jumlahTanpaNatrium: (r['tanpa_natrium'] as num).toInt(),
      jumlahTanpaLemak: (r['tanpa_lemak'] as num).toInt(),
    );
  }

  Future<Map<String, ({double gula, double natrium, double lemak})>> ringkasanRentang(
    DateTime dari,
    DateTime sampai,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT
        tanggal,
        COALESCE(SUM(gula_g), 0) AS total_gula,
        COALESCE(SUM(natrium_mg), 0) AS total_natrium,
        COALESCE(SUM(lemak_total_g), 0) AS total_lemak
      FROM konsumsi
      WHERE tanggal >= ? AND tanggal <= ?
      GROUP BY tanggal
      ''',
      [tanggalLokal(dari), tanggalLokal(sampai)],
    );
    return {
      for (final r in rows)
        r['tanggal'] as String: (
          gula: (r['total_gula'] as num).toDouble(),
          natrium: (r['total_natrium'] as num).toDouble(),
          lemak: (r['total_lemak'] as num).toDouble(),
        ),
    };
  }

  /// Ringkasan minggu (Senin sampai Minggu lokal) yang memuat [tanggalDalamMinggu].
  /// Hari tanpa catatan tidak dihitung di bawah batas; rata-rata dihitung dari hari yang ada catatan.
  Future<RingkasanMinggu> ringkasanMinggu(
    DateTime tanggalDalamMinggu, {
    double batasGula = batasGulaHarianG,
  }) async {
    final l = tanggalDalamMinggu.isUtc ? tanggalDalamMinggu.toLocal() : tanggalDalamMinggu;
    final senin = DateTime(l.year, l.month, l.day - (l.weekday - DateTime.monday));
    final minggu = senin.add(const Duration(days: 6));
    final rows = await _db.rawQuery(
      '''
      SELECT
        tanggal,
        COUNT(*) AS jumlah_catatan,
        COALESCE(SUM(gula_g), 0) AS total_gula,
        COALESCE(SUM(natrium_mg), 0) AS total_natrium,
        COALESCE(SUM(lemak_total_g), 0) AS total_lemak
      FROM konsumsi
      WHERE tanggal >= ? AND tanggal <= ?
      GROUP BY tanggal
      ''',
      [tanggalLokal(senin), tanggalLokal(minggu)],
    );

    var jumlahCatatan = 0;
    var hariDiBawahBatas = 0;
    var totalGula = 0.0;
    var totalNatrium = 0.0;
    var totalLemak = 0.0;

    for (final r in rows) {
      final g = (r['total_gula'] as num).toDouble();
      final n = (r['total_natrium'] as num).toDouble();
      final f = (r['total_lemak'] as num).toDouble();
      jumlahCatatan += (r['jumlah_catatan'] as num).toInt();
      if (g <= batasGula) hariDiBawahBatas++;
      totalGula += g;
      totalNatrium += n;
      totalLemak += f;
    }

    final hariAdaCatatan = rows.length;
    return RingkasanMinggu(
      awalMinggu: senin,
      akhirMinggu: minggu,
      jumlahCatatan: jumlahCatatan,
      hariAdaCatatan: hariAdaCatatan,
      hariGulaDiBawahBatas: hariDiBawahBatas,
      totalGula: totalGula,
      rataGula: hariAdaCatatan == 0 ? 0 : totalGula / hariAdaCatatan,
      rataNatrium: hariAdaCatatan == 0 ? 0 : totalNatrium / hariAdaCatatan,
      rataLemak: hariAdaCatatan == 0 ? 0 : totalLemak / hariAdaCatatan,
    );
  }

  /// Daftar produk teratas menurut total gula dalam minggu (Senin-Minggu lokal).
  Future<List<PenyumbangGula>> penyumbangGulaMinggu(DateTime tanggalDalamMinggu, {int batas = 3}) async {
    if (batas <= 0) {
      throw ArgumentError.value(batas, 'batas', 'Harus lebih dari 0');
    }
    final l = tanggalDalamMinggu.isUtc ? tanggalDalamMinggu.toLocal() : tanggalDalamMinggu;
    final senin = DateTime(l.year, l.month, l.day - (l.weekday - DateTime.monday));
    final minggu = senin.add(const Duration(days: 6));
    final dari = tanggalLokal(senin);
    final sampai = tanggalLokal(minggu);

    final totalRows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(gula_g), 0) AS total_gula
      FROM konsumsi
      WHERE tanggal >= ? AND tanggal <= ? AND gula_g IS NOT NULL AND gula_g > 0
      ''',
      [dari, sampai],
    );
    final totalMinggu = (totalRows.first['total_gula'] as num).toDouble();
    if (totalMinggu <= 0) return const [];

    final rows = await _db.rawQuery(
      '''
      SELECT
        MIN(p.nama) AS nama,
        SUM(k.gula_g) AS total_gula,
        COUNT(*) AS jumlah_kali
      FROM konsumsi k
      JOIN produk p ON p.id = k.produk_id
      WHERE k.tanggal >= ? AND k.tanggal <= ? AND k.gula_g IS NOT NULL AND k.gula_g > 0
      GROUP BY LOWER(TRIM(p.nama))
      ORDER BY total_gula DESC, jumlah_kali DESC, nama ASC
      LIMIT ?
      ''',
      [dari, sampai, batas],
    );

    return [
      for (final r in rows)
        PenyumbangGula(
          nama: r['nama'] as String,
          totalGula: (r['total_gula'] as num).toDouble(),
          persen: (r['total_gula'] as num).toDouble() / totalMinggu,
          jumlahKali: (r['jumlah_kali'] as num).toInt(),
        ),
    ];
  }

  /// Perbarui jumlah_sajian dan nilai gula/natrium/lemak baris = nilai produk x [porsiBaru].
  Future<BarisRiwayat?> ubahPorsi(int konsumsiId, double porsiBaru) async {
    if (porsiBaru <= 0) {
      throw ArgumentError.value(porsiBaru, 'porsiBaru', 'Harus lebih dari 0');
    }
    return _db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT
          k.id,
          k.produk_id,
          p.nama,
          p.gula_g AS produk_gula,
          p.natrium_mg AS produk_natrium,
          p.lemak_total_g AS produk_lemak,
          k.tanggal,
          k.dibuat_pada
        FROM konsumsi k
        JOIN produk p ON p.id = k.produk_id
        WHERE k.id = ?
        ''',
        [konsumsiId],
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      final pGula = (r['produk_gula'] as num?)?.toDouble();
      final pNatrium = (r['produk_natrium'] as num?)?.toDouble();
      final pLemak = (r['produk_lemak'] as num?)?.toDouble();

      final gulaBaru = pGula == null ? null : pGula * porsiBaru;
      final natriumBaru = pNatrium == null ? null : pNatrium * porsiBaru;
      final lemakBaru = pLemak == null ? null : pLemak * porsiBaru;

      await txn.update(
        'konsumsi',
        {
          'jumlah_sajian': porsiBaru,
          'gula_g': gulaBaru,
          'natrium_mg': natriumBaru,
          'lemak_total_g': lemakBaru,
        },
        where: 'id = ?',
        whereArgs: [konsumsiId],
      );

      return BarisRiwayat(
        id: (r['id'] as num).toInt(),
        produkId: (r['produk_id'] as num).toInt(),
        nama: r['nama'] as String,
        jumlahSajian: porsiBaru,
        gulaG: gulaBaru,
        natriumMg: natriumBaru,
        lemakTotalG: lemakBaru,
        tanggal: r['tanggal'] as String,
        dibuatPada: (r['dibuat_pada'] as num).toInt(),
      );
    });
  }

  /// Catat produk dan porsi yang sama dengan [konsumsiId] untuk tanggal [waktuLokal].
  Future<int> catatUlang(int konsumsiId, {required DateTime waktuLokal}) async {
    final lokal = waktuLokal.isUtc ? waktuLokal.toLocal() : waktuLokal;
    final tgl = tanggalLokal(lokal);
    final epochMs = lokal.millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      final rows = await txn.query('konsumsi', where: 'id = ?', whereArgs: [konsumsiId], limit: 1);
      if (rows.isEmpty) {
        throw StateError('Catatan konsumsi #$konsumsiId tidak ditemukan');
      }
      final asal = rows.first;
      return txn.insert('konsumsi', {
        'produk_id': asal['produk_id'],
        'jumlah_sajian': asal['jumlah_sajian'],
        'gula_g': asal['gula_g'],
        'natrium_mg': asal['natrium_mg'],
        'lemak_total_g': asal['lemak_total_g'],
        'tanggal': tgl,
        'dibuat_pada': epochMs,
      });
    });
  }

  /// Daftar produk yang memiliki minimal satu catatan konsumsi, dikelompokkan per nama.
  Future<List<ProdukRingkas>> daftarProduk({
    UrutanProduk urutan = UrutanProduk.sering,
    int? batas,
  }) async {
    if (batas != null && batas <= 0) {
      throw ArgumentError.value(batas, 'batas', 'Harus lebih dari 0');
    }
    final orderBy = switch (urutan) {
      UrutanProduk.sering => 'agg.jumlah_kali DESC, agg.terakhir_dicatat DESC, p.nama COLLATE NOCASE ASC',
      UrutanProduk.terbaru => 'agg.terakhir_dicatat DESC, p.id DESC, p.nama COLLATE NOCASE ASC',
    };
    final limitSql = batas == null ? '' : 'LIMIT ?';
    final rows = await _db.rawQuery(
      '''
      SELECT
        p.id AS produk_id,
        p.nama,
        p.gula_g,
        p.natrium_mg,
        p.lemak_total_g,
        p.takaran_saji_jumlah,
        p.takaran_saji_satuan,
        p.sajian_per_kemasan,
        agg.jumlah_kali,
        agg.terakhir_dicatat
      FROM (
        SELECT
          LOWER(TRIM(p2.nama)) AS kunci_nama,
          COUNT(*) AS jumlah_kali,
          MAX(k2.dibuat_pada) AS terakhir_dicatat,
          MAX(p2.id) AS produk_id_terbaru
        FROM konsumsi k2
        JOIN produk p2 ON p2.id = k2.produk_id
        GROUP BY LOWER(TRIM(p2.nama))
      ) agg
      JOIN produk p ON p.id = agg.produk_id_terbaru
      ORDER BY $orderBy
      $limitSql
      ''',
      [?batas],
    );

    return [
      for (final r in rows)
        ProdukRingkas(
          id: (r['produk_id'] as num).toInt(),
          nama: r['nama'] as String,
          gulaG: (r['gula_g'] as num?)?.toDouble(),
          natriumMg: (r['natrium_mg'] as num?)?.toDouble(),
          lemakTotalG: (r['lemak_total_g'] as num?)?.toDouble(),
          takaranJumlah: (r['takaran_saji_jumlah'] as num?)?.toDouble(),
          takaranSatuan: r['takaran_saji_satuan'] as String?,
          sajianPerKemasan: (r['sajian_per_kemasan'] as num?)?.toDouble(),
          jumlahKali: (r['jumlah_kali'] as num).toInt(),
          terakhirDicatat: (r['terakhir_dicatat'] as num).toInt(),
        ),
    ];
  }

  /// Catat konsumsi hari ini dari produk [produkId] dengan nilai produk x [jumlahSajian].
  Future<int> catatProduk(
    int produkId, {
    required double jumlahSajian,
    required DateTime waktuLokal,
  }) async {
    if (jumlahSajian <= 0) {
      throw ArgumentError.value(jumlahSajian, 'jumlahSajian', 'Harus lebih dari 0');
    }
    final lokal = waktuLokal.isUtc ? waktuLokal.toLocal() : waktuLokal;
    final tgl = tanggalLokal(lokal);
    final epochMs = lokal.millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      final rows = await txn.query('produk', where: 'id = ?', whereArgs: [produkId], limit: 1);
      if (rows.isEmpty) {
        throw StateError('Produk #$produkId tidak ditemukan');
      }
      final p = rows.first;
      final gula = (p['gula_g'] as num?)?.toDouble();
      final natrium = (p['natrium_mg'] as num?)?.toDouble();
      final lemak = (p['lemak_total_g'] as num?)?.toDouble();
      return txn.insert('konsumsi', {
        'produk_id': produkId,
        'jumlah_sajian': jumlahSajian,
        'gula_g': gula == null ? null : gula * jumlahSajian,
        'natrium_mg': natrium == null ? null : natrium * jumlahSajian,
        'lemak_total_g': lemak == null ? null : lemak * jumlahSajian,
        'tanggal': tgl,
        'dibuat_pada': epochMs,
      });
    });
  }

  Future<List<BarisRiwayat>> halamanRiwayat({
    int batas = 30,
    ({String tanggal, int id})? sebelum,
  }) async {
    if (batas <= 0) {
      throw ArgumentError.value(batas, 'batas', 'Harus lebih dari 0');
    }
    final rows = sebelum == null
        ? await _db.rawQuery(
            '''
            SELECT k.id, k.produk_id, p.nama, k.jumlah_sajian, k.gula_g, k.natrium_mg, k.lemak_total_g, k.tanggal, k.dibuat_pada
            FROM konsumsi k
            JOIN produk p ON p.id = k.produk_id
            ORDER BY k.tanggal DESC, k.id DESC
            LIMIT ?
            ''',
            [batas],
          )
        : await _db.rawQuery(
            '''
            SELECT k.id, k.produk_id, p.nama, k.jumlah_sajian, k.gula_g, k.natrium_mg, k.lemak_total_g, k.tanggal, k.dibuat_pada
            FROM konsumsi k
            JOIN produk p ON p.id = k.produk_id
            WHERE k.tanggal < ? OR (k.tanggal = ? AND k.id < ?)
            ORDER BY k.tanggal DESC, k.id DESC
            LIMIT ?
            ''',
            [sebelum.tanggal, sebelum.tanggal, sebelum.id, batas],
          );

    return rows.map(_barisDariMap).toList();
  }

  /// Hapus satu baris konsumsi tanpa menghapus produk. Mengembalikan salinan untuk undo.
  Future<BarisRiwayat?> hapusKonsumsi(int id) async {
    return _db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT k.id, k.produk_id, p.nama, k.jumlah_sajian, k.gula_g, k.natrium_mg, k.lemak_total_g, k.tanggal, k.dibuat_pada
        FROM konsumsi k
        JOIN produk p ON p.id = k.produk_id
        WHERE k.id = ?
        ''',
        [id],
      );
      if (rows.isEmpty) return null;
      await txn.delete('konsumsi', where: 'id = ?', whereArgs: [id]);
      return _barisDariMap(rows.first);
    });
  }

  /// Pulihkan baris konsumsi yang baru dihapus (untuk Urungkan 4 detik).
  Future<int> pulihkanKonsumsi(BarisRiwayat baris) => _db.insert('konsumsi', {
        'id': baris.id,
        'produk_id': baris.produkId,
        'jumlah_sajian': baris.jumlahSajian,
        'gula_g': baris.gulaG,
        'natrium_mg': baris.natriumMg,
        'lemak_total_g': baris.lemakTotalG,
        'tanggal': baris.tanggal,
        'dibuat_pada': baris.dibuatPada,
      });

  Future<void> hapusSemuaData() async {
    await _db.transaction((txn) async {
      await txn.delete('konsumsi');
      await txn.delete('produk');
      await txn.delete('pengaturan');
      await txn.delete('tantangan');
    });
  }

  Future<int> jumlahKonsumsi() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) FROM konsumsi');
    return (rows.single.values.single as num).toInt();
  }

  Future<int> jumlahProduk() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) FROM produk');
    return (rows.single.values.single as num).toInt();
  }

  /// Baca jumlah pindai terpakai dan bonus iklan minggu berjalan; reset otomatis bila masuk Senin baru.
  Future<({int terpakai, int bonusIklan})> bacaStatusKuota(DateTime hari) async {
    final mingguIni = awalMingguLokal(hari);
    final mingguTersimpan = await bacaPengaturan(kunciKuotaMinggu);
    if (mingguTersimpan != mingguIni) {
      await _db.transaction((txn) async {
        await txn.insert(
          'pengaturan',
          {'kunci': kunciKuotaMinggu, 'nilai': mingguIni},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'pengaturan',
          {'kunci': kunciKuotaTerpakai, 'nilai': '0'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'pengaturan',
          {'kunci': kunciKuotaBonusIklan, 'nilai': '0'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      return (terpakai: 0, bonusIklan: 0);
    }
    final rawPakai = await bacaPengaturan(kunciKuotaTerpakai);
    final rawBonus = await bacaPengaturan(kunciKuotaBonusIklan);
    final terpakai = int.tryParse(rawPakai ?? '') ?? 0;
    final bonus = int.tryParse(rawBonus ?? '') ?? 0;
    return (
      terpakai: terpakai < 0 ? 0 : terpakai,
      bonusIklan: bonus < 0 ? 0 : bonus,
    );
  }

  /// Baca jumlah pindai terpakai pada minggu berjalan; reset otomatis bila masuk Senin baru.
  Future<int> bacaKuotaTerpakai(DateTime hari) async => (await bacaStatusKuota(hari)).terpakai;

  /// Baca jumlah bonus iklan terpakai pada minggu berjalan; reset otomatis bila masuk Senin baru.
  Future<int> bacaKuotaBonusIklan(DateTime hari) async => (await bacaStatusKuota(hari)).bonusIklan;

  /// Tambah penghitung kuota terpakai minggu ini di tabel pengaturan.
  Future<int> tambahKuotaTerpakai(DateTime hari, {int maks = 15}) async {
    final mingguIni = awalMingguLokal(hari);
    return _db.transaction((txn) async {
      final rowsMinggu = await txn.query(
        'pengaturan',
        columns: ['nilai'],
        where: 'kunci = ?',
        whereArgs: [kunciKuotaMinggu],
        limit: 1,
      );
      final mingguTersimpan = rowsMinggu.isEmpty ? null : rowsMinggu.first['nilai'] as String?;
      var terpakai = 0;
      var bonus = 0;
      if (mingguTersimpan == mingguIni) {
        final rowsPakai = await txn.query(
          'pengaturan',
          columns: ['nilai'],
          where: 'kunci = ?',
          whereArgs: [kunciKuotaTerpakai],
          limit: 1,
        );
        final rowsBonus = await txn.query(
          'pengaturan',
          columns: ['nilai'],
          where: 'kunci = ?',
          whereArgs: [kunciKuotaBonusIklan],
          limit: 1,
        );
        final parsed = rowsPakai.isEmpty ? null : int.tryParse(rowsPakai.first['nilai'] as String? ?? '');
        final parsedBonus = rowsBonus.isEmpty ? null : int.tryParse(rowsBonus.first['nilai'] as String? ?? '');
        terpakai = (parsed == null || parsed < 0) ? 0 : parsed;
        bonus = (parsedBonus == null || parsedBonus < 0) ? 0 : parsedBonus;
      }
      final baru = (terpakai + 1).clamp(0, maks);
      await txn.insert(
        'pengaturan',
        {'kunci': kunciKuotaMinggu, 'nilai': mingguIni},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'pengaturan',
        {'kunci': kunciKuotaTerpakai, 'nilai': '$baru'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'pengaturan',
        {'kunci': kunciKuotaBonusIklan, 'nilai': '$bonus'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return baru;
    });
  }

  /// Tambah +1 bonus kuota iklan minggu ini; nilai baru dijepit 0..[maks].
  Future<int> tambahKuotaBonusIklan(DateTime hari, {int maks = 10}) async {
    final mingguIni = awalMingguLokal(hari);
    return _db.transaction((txn) async {
      final rowsMinggu = await txn.query(
        'pengaturan',
        columns: ['nilai'],
        where: 'kunci = ?',
        whereArgs: [kunciKuotaMinggu],
        limit: 1,
      );
      final mingguTersimpan = rowsMinggu.isEmpty ? null : rowsMinggu.first['nilai'] as String?;
      var terpakai = 0;
      var bonus = 0;
      if (mingguTersimpan == mingguIni) {
        final rowsPakai = await txn.query(
          'pengaturan',
          columns: ['nilai'],
          where: 'kunci = ?',
          whereArgs: [kunciKuotaTerpakai],
          limit: 1,
        );
        final rowsBonus = await txn.query(
          'pengaturan',
          columns: ['nilai'],
          where: 'kunci = ?',
          whereArgs: [kunciKuotaBonusIklan],
          limit: 1,
        );
        final parsedPakai = rowsPakai.isEmpty ? null : int.tryParse(rowsPakai.first['nilai'] as String? ?? '');
        final parsedBonus = rowsBonus.isEmpty ? null : int.tryParse(rowsBonus.first['nilai'] as String? ?? '');
        terpakai = (parsedPakai == null || parsedPakai < 0) ? 0 : parsedPakai;
        bonus = (parsedBonus == null || parsedBonus < 0) ? 0 : parsedBonus;
      }
      final bonusBaru = (bonus + 1).clamp(0, maks);
      await txn.insert(
        'pengaturan',
        {'kunci': kunciKuotaMinggu, 'nilai': mingguIni},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'pengaturan',
        {'kunci': kunciKuotaTerpakai, 'nilai': '$terpakai'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'pengaturan',
        {'kunci': kunciKuotaBonusIklan, 'nilai': '$bonusBaru'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return bonusBaru;
    });
  }

  /// Ekspor seluruh data lokal (produk, konsumsi, pengaturan) sebagai JSON rapi.
  Future<String> eksporDataJson({DateTime? sekarang}) async {
    final produkRows = await _db.query('produk', orderBy: 'id ASC');
    final konsumsiRows = await _db.query('konsumsi', orderBy: 'tanggal ASC, id ASC');
    final pengaturanRows = await _db.query('pengaturan', orderBy: 'kunci ASC');
    final waktu = sekarang ?? DateTime.now();

    final payload = {
      'aplikasi': 'JeliLabel',
      'versiSkema': 2,
      'dieksporPada': (waktu.isUtc ? waktu.toLocal() : waktu).toIso8601String(),
      'pengaturan': {
        for (final r in pengaturanRows) r['kunci'] as String: r['nilai'] as String,
      },
      'produk': produkRows,
      'konsumsi': konsumsiRows,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Ekspor seluruh data lokal (produk, konsumsi, pengaturan) sebagai CSV RFC 4180.
  Future<String> eksporDataCsv() async {
    final produkRows = await _db.query('produk', orderBy: 'id ASC');
    final konsumsiRows = await _db.query('konsumsi', orderBy: 'tanggal ASC, id ASC');
    final pengaturanRows = await _db.query('pengaturan', orderBy: 'kunci ASC');

    const kolom = [
      'tabel',
      'id',
      'produk_id',
      'nama',
      'takaran_saji_jumlah',
      'takaran_saji_satuan',
      'sajian_per_kemasan',
      'gula_g',
      'natrium_mg',
      'energi_kkal',
      'lemak_total_g',
      'protein_g',
      'karbohidrat_g',
      'sumber',
      'jumlah_sajian',
      'tanggal',
      'dibuat_pada',
      'kunci',
      'nilai',
    ];

    final baris = <String>[kolom.join(',')];

    for (final p in produkRows) {
      baris.add([
        'produk',
        p['id'],
        null,
        p['nama'],
        p['takaran_saji_jumlah'],
        p['takaran_saji_satuan'],
        p['sajian_per_kemasan'],
        p['gula_g'],
        p['natrium_mg'],
        p['energi_kkal'],
        p['lemak_total_g'],
        p['protein_g'],
        p['karbohidrat_g'],
        p['sumber'],
        null,
        null,
        p['dibuat_pada'],
        null,
        null,
      ].map(_selCsv).join(','));
    }

    for (final k in konsumsiRows) {
      baris.add([
        'konsumsi',
        k['id'],
        k['produk_id'],
        null,
        null,
        null,
        null,
        k['gula_g'],
        k['natrium_mg'],
        null,
        k['lemak_total_g'],
        null,
        null,
        null,
        k['jumlah_sajian'],
        k['tanggal'],
        k['dibuat_pada'],
        null,
        null,
      ].map(_selCsv).join(','));
    }

    for (final s in pengaturanRows) {
      baris.add([
        'pengaturan',
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        s['kunci'],
        s['nilai'],
      ].map(_selCsv).join(','));
    }

    return baris.join('\n');
  }

  static String _selCsv(Object? nilai) {
    if (nilai == null) return '';
    final s = nilai.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<String?> bacaPengaturan(String kunci) async {
    final rows = await _db.query('pengaturan', columns: ['nilai'], where: 'kunci = ?', whereArgs: [kunci], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['nilai'] as String?;
  }

  Future<void> tulisPengaturan(String kunci, String nilai) async {
    await _db.insert(
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> perkenalanSelesai() async => (await bacaPengaturan(kunciPerkenalanSelesai)) == '1';

  Future<void> tandaiPerkenalanSelesai() => tulisPengaturan(kunciPerkenalanSelesai, '1');

  String _kunciPeringatan(String zat) => switch (zat) {
        'gula' => kunciPeringatanGulaTanggal,
        'natrium' => kunciPeringatanNatriumTanggal,
        'lemak' => kunciPeringatanLemakTanggal,
        _ => throw ArgumentError.value(zat, 'zat', "Hanya 'gula', 'natrium', atau 'lemak'"),
      };

  Future<bool> bolehPeringatan(String zat, DateTime hari) async {
    final kunci = _kunciPeringatan(zat);
    final terakhir = await bacaPengaturan(kunci);
    return terakhir != tanggalLokal(hari);
  }

  Future<void> tandaiPeringatan(String zat, DateTime hari) =>
      tulisPengaturan(_kunciPeringatan(zat), tanggalLokal(hari));

  BarisRiwayat _barisDariMap(Map<String, Object?> r) => BarisRiwayat(
        id: (r['id'] as num).toInt(),
        produkId: (r['produk_id'] as num).toInt(),
        nama: r['nama'] as String,
        jumlahSajian: (r['jumlah_sajian'] as num).toDouble(),
        gulaG: (r['gula_g'] as num?)?.toDouble(),
        natriumMg: (r['natrium_mg'] as num?)?.toDouble(),
        lemakTotalG: (r['lemak_total_g'] as num?)?.toDouble(),
        tanggal: r['tanggal'] as String,
        dibuatPada: (r['dibuat_pada'] as num).toInt(),
      );
}
