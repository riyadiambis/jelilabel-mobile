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

/// Hasil baca label (per sajian), masih draf sampai pengguna menekan Simpan.
class DrafProduk extends Equatable {
  const DrafProduk({
    required this.nama,
    this.gulaG,
    this.natriumMg,
    this.takaranJumlah,
    this.takaranSatuan,
    this.sajianPerKemasan,
    this.cekLagiNatrium = false,
  });

  final String nama;
  final double? gulaG;
  final double? natriumMg;
  final double? takaranJumlah;
  final String? takaranSatuan;
  final double? sajianPerKemasan;
  final bool cekLagiNatrium;

  static const kosong = DrafProduk(nama: '');

  @override
  List<Object?> get props => [nama, gulaG, natriumMg, takaranJumlah, takaranSatuan, sajianPerKemasan, cekLagiNatrium];
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
    required this.tanggal,
    required this.dibuatPada,
  });

  final int id;
  final int produkId;
  final String nama;
  final double jumlahSajian;
  final double? gulaG;
  final double? natriumMg;
  final String tanggal;
  final int dibuatPada;

  DateTime get waktu => DateTime.fromMillisecondsSinceEpoch(dibuatPada);

  DateTime get tanggalLokalObjek {
    final bagian = tanggal.split('-');
    return DateTime(int.parse(bagian[0]), int.parse(bagian[1]), int.parse(bagian[2]));
  }

  StatusGizi get status => statusPorsi(gulaG, natriumMg);

  @override
  List<Object?> get props => [id, produkId, nama, jumlahSajian, gulaG, natriumMg, tanggal, dibuatPada];
}

/// Ringkasan asupan harian dari SQLite.
class RingkasanHari extends Equatable {
  const RingkasanHari({
    this.totalGula = 0,
    this.totalNatrium = 0,
    this.jumlahCatatan = 0,
    this.jumlahTanpaGula = 0,
    this.jumlahTanpaNatrium = 0,
  });

  final double totalGula;
  final double totalNatrium;
  final int jumlahCatatan;
  final int jumlahTanpaGula;
  final int jumlahTanpaNatrium;

  @override
  List<Object?> get props => [totalGula, totalNatrium, jumlahCatatan, jumlahTanpaGula, jumlahTanpaNatrium];
}

/// Satu-satunya pintu akses basis data lokal untuk fitur asupan dan pengaturan.
class AsupanRepository {
  AsupanRepository(this._db);

  final Database _db;

  static const kunciPerkenalanSelesai = 'perkenalan_selesai';
  static const kunciPeringatanGulaTanggal = 'peringatan_gula_tanggal';
  static const kunciPeringatanNatriumTanggal = 'peringatan_natrium_tanggal';

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
        'lemak_total_g': null,
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
        COUNT(*) AS jumlah_catatan,
        COALESCE(SUM(CASE WHEN gula_g IS NULL THEN 1 ELSE 0 END), 0) AS tanpa_gula,
        COALESCE(SUM(CASE WHEN natrium_mg IS NULL THEN 1 ELSE 0 END), 0) AS tanpa_natrium
      FROM konsumsi
      WHERE tanggal = ?
      ''',
      [tgl],
    );
    final r = rows.first;
    return RingkasanHari(
      totalGula: (r['total_gula'] as num).toDouble(),
      totalNatrium: (r['total_natrium'] as num).toDouble(),
      jumlahCatatan: (r['jumlah_catatan'] as num).toInt(),
      jumlahTanpaGula: (r['tanpa_gula'] as num).toInt(),
      jumlahTanpaNatrium: (r['tanpa_natrium'] as num).toInt(),
    );
  }

  Future<Map<String, ({double gula, double natrium})>> ringkasanRentang(DateTime dari, DateTime sampai) async {
    final rows = await _db.rawQuery(
      '''
      SELECT
        tanggal,
        COALESCE(SUM(gula_g), 0) AS total_gula,
        COALESCE(SUM(natrium_mg), 0) AS total_natrium
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
        ),
    };
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
            SELECT k.id, k.produk_id, p.nama, k.jumlah_sajian, k.gula_g, k.natrium_mg, k.tanggal, k.dibuat_pada
            FROM konsumsi k
            JOIN produk p ON p.id = k.produk_id
            ORDER BY k.tanggal DESC, k.id DESC
            LIMIT ?
            ''',
            [batas],
          )
        : await _db.rawQuery(
            '''
            SELECT k.id, k.produk_id, p.nama, k.jumlah_sajian, k.gula_g, k.natrium_mg, k.tanggal, k.dibuat_pada
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
        SELECT k.id, k.produk_id, p.nama, k.jumlah_sajian, k.gula_g, k.natrium_mg, k.tanggal, k.dibuat_pada
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
        'tanggal': baris.tanggal,
        'dibuat_pada': baris.dibuatPada,
      });

  Future<void> hapusSemuaData() async {
    await _db.transaction((txn) async {
      await txn.delete('konsumsi');
      await txn.delete('produk');
      await txn.delete('pengaturan');
    });
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
        _ => throw ArgumentError.value(zat, 'zat', "Hanya 'gula' atau 'natrium'"),
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
        tanggal: r['tanggal'] as String,
        dibuatPada: (r['dibuat_pada'] as num).toInt(),
      );
}
