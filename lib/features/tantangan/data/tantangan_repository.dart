import 'package:equatable/equatable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/ambang.dart';
import '../../asupan/data/asupan_repository.dart' show tanggalLokal;
import '../domain/jenis_tantangan.dart';

class StatusSemuaTantangan extends Equatable {
  const StatusSemuaTantangan({
    this.berjalan,
    this.berakhirTerbaru,
    this.lencana = const [],
    this.ucapanTercapai,
  });

  final KemajuanTantangan? berjalan;
  final KemajuanTantangan? berakhirTerbaru;
  final List<LencanaTantangan> lencana;
  final LencanaTantangan? ucapanTercapai;

  @override
  List<Object?> get props => [berjalan, berakhirTerbaru, lencana, ucapanTercapai];
}

/// Pintu akses SQLite untuk fitur tantangan dan lencana (tabel tantangan + baca konsumsi).
class TantanganRepository {
  TantanganRepository(this._db);

  final Database _db;

  static const kunciUcapanTantanganId = 'tantangan_ucapan_id';
  static const _kunciProfilAktif = 'profil_aktif';

  /// Membaca seluruh tantangan, menghitung kemajuan tantangan berjalan dari tabel konsumsi profil aktif,
  /// lalu memperbarui status menjadi 'selesai' atau 'berakhir' bila waktunya.
  Future<StatusSemuaTantangan> bacaStatus({
    required DateTime waktuSekarang,
    BatasHarian batas = BatasHarian.kemenkes,
  }) async {
    final lokal = waktuSekarang.isUtc ? waktuSekarang.toLocal() : waktuSekarang;
    final hariIni = DateTime(lokal.year, lokal.month, lokal.day);
    final waktuMs = lokal.millisecondsSinceEpoch;

    return _db.transaction((txn) async {
      final profilId = await _bacaProfilAktifId(txn);
      final hasilEvaluasi = await _evaluasiBerjalan(
        txn,
        hariIni: hariIni,
        waktuMs: waktuMs,
        batas: batas,
        profilId: profilId,
      );

      final rows = await txn.query('tantangan', orderBy: 'id DESC');
      final lencana = <LencanaTantangan>[];
      KemajuanTantangan? berakhirTerbaru;

      if (hasilEvaluasi.berjalan == null && rows.isNotEmpty) {
        final terbaru = rows.first;
        if (terbaru['status'] == StatusTantangan.berakhir.kode) {
          final jenis = JenisTantangan.dariKode(terbaru['jenis'] as String);
          if (jenis != null) {
            final mulai = _uraiTanggal(terbaru['mulai'] as String);
            final harian = await _bacaRingkasanHarian(txn, mulai: mulai, profilId: profilId);
            berakhirTerbaru = hitungKemajuanTantangan(
              id: (terbaru['id'] as num).toInt(),
              jenis: jenis,
              mulai: mulai,
              status: StatusTantangan.berakhir,
              selesaiPada: null,
              hariIni: hariIni,
              harian: harian,
              batas: batas,
            );
          }
        }
      }

      for (final r in rows) {
        if (r['status'] == StatusTantangan.selesai.kode) {
          final jenis = JenisTantangan.dariKode(r['jenis'] as String);
          final selesaiPada = (r['selesai_pada'] as num?)?.toInt();
          if (jenis != null && selesaiPada != null) {
            lencana.add(
              LencanaTantangan(
                id: (r['id'] as num).toInt(),
                jenis: jenis,
                selesaiPada: selesaiPada,
              ),
            );
          }
        }
      }

      LencanaTantangan? ucapanTercapai;
      if (lencana.isNotEmpty) {
        final ackRows = await txn.query(
          'pengaturan',
          columns: ['nilai'],
          where: 'kunci = ?',
          whereArgs: [kunciUcapanTantanganId],
          limit: 1,
        );
        final ackId = ackRows.isEmpty ? 0 : (int.tryParse(ackRows.first['nilai'] as String? ?? '') ?? 0);
        final terbaruLencana = lencana.first;
        if (terbaruLencana.id > ackId) {
          ucapanTercapai = terbaruLencana;
        }
      }

      return StatusSemuaTantangan(
        berjalan: hasilEvaluasi.berjalan,
        berakhirTerbaru: berakhirTerbaru,
        lencana: lencana,
        ucapanTercapai: ucapanTercapai,
      );
    });
  }

  /// Memulai tantangan baru bila belum ada tantangan yang sedang berjalan.
  Future<int> mulaiTantangan(JenisTantangan jenis, {required DateTime waktuSekarang}) async {
    final lokal = waktuSekarang.isUtc ? waktuSekarang.toLocal() : waktuSekarang;
    final hariIni = DateTime(lokal.year, lokal.month, lokal.day);
    final waktuMs = lokal.millisecondsSinceEpoch;

    return _db.transaction((txn) async {
      final profilId = await _bacaProfilAktifId(txn);
      await _evaluasiBerjalan(txn, hariIni: hariIni, waktuMs: waktuMs, profilId: profilId);
      final aktif = await txn.query(
        'tantangan',
        columns: ['id'],
        where: 'status = ?',
        whereArgs: [StatusTantangan.berjalan.kode],
        limit: 1,
      );
      if (aktif.isNotEmpty) {
        throw StateError('Masih ada tantangan yang sedang berjalan');
      }

      return txn.insert('tantangan', {
        'jenis': jenis.kode,
        'mulai': tanggalLokal(hariIni),
        'selesai_pada': null,
        'status': StatusTantangan.berjalan.kode,
      });
    });
  }

  /// Menandai lembar ucapan "Tantangan tercapai!" sudah ditampilkan untuk tantangan [tantanganId].
  Future<void> tandaiUcapanTercapai(int tantanganId) => _db.insert(
        'pengaturan',
        {'kunci': kunciUcapanTantanganId, 'nilai': '$tantanganId'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<({KemajuanTantangan? berjalan})> _evaluasiBerjalan(
    Transaction txn, {
    required DateTime hariIni,
    required int waktuMs,
    BatasHarian batas = BatasHarian.kemenkes,
    int? profilId,
  }) async {
    final berjalanRows = await txn.query(
      'tantangan',
      where: 'status = ?',
      whereArgs: [StatusTantangan.berjalan.kode],
      orderBy: 'id DESC',
    );
    if (berjalanRows.isEmpty) return (berjalan: null);

    KemajuanTantangan? masihBerjalan;

    for (final row in berjalanRows) {
      final id = (row['id'] as num).toInt();
      final jenis = JenisTantangan.dariKode(row['jenis'] as String);
      if (jenis == null) {
        await txn.update(
          'tantangan',
          {'status': StatusTantangan.berakhir.kode},
          where: 'id = ?',
          whereArgs: [id],
        );
        continue;
      }

      final mulai = _uraiTanggal(row['mulai'] as String);
      final harian = await _bacaRingkasanHarian(txn, mulai: mulai, profilId: profilId);
      final kemajuan = hitungKemajuanTantangan(
        id: id,
        jenis: jenis,
        mulai: mulai,
        status: StatusTantangan.berjalan,
        selesaiPada: null,
        hariIni: hariIni,
        harian: harian,
        batas: batas,
      );

      if (kemajuan.tercapai) {
        await txn.update(
          'tantangan',
          {
            'status': StatusTantangan.selesai.kode,
            'selesai_pada': waktuMs,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else if (kemajuan.jendelaLewat) {
        await txn.update(
          'tantangan',
          {'status': StatusTantangan.berakhir.kode},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        masihBerjalan ??= kemajuan;
      }
    }

    return (berjalan: masihBerjalan);
  }

  Future<int?> _bacaProfilAktifId(Transaction txn) async {
    final rows = await txn.query(
      'pengaturan',
      columns: ['nilai'],
      where: 'kunci = ?',
      whereArgs: [_kunciProfilAktif],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final parsed = int.tryParse(rows.first['nilai'] as String? ?? '');
      if (parsed != null) {
        final ada = await txn.query('profil', columns: ['id'], where: 'id = ?', whereArgs: [parsed], limit: 1);
        if (ada.isNotEmpty) return parsed;
      }
    }
    final pertama = await txn.query('profil', columns: ['id'], orderBy: 'id ASC', limit: 1);
    if (pertama.isEmpty) return null;
    return (pertama.first['id'] as num).toInt();
  }

  Future<Map<String, RingkasanHariTantangan>> _bacaRingkasanHarian(
    Transaction txn, {
    required DateTime mulai,
    int? profilId,
  }) async {
    if (profilId == null) return const {};
    final akhir = DateTime(mulai.year, mulai.month, mulai.day + (jendelaTantanganHari - 1));
    final rows = await txn.rawQuery(
      '''
      SELECT
        tanggal,
        COUNT(*) AS jumlah_catatan,
        COUNT(gula_g) AS ada_gula,
        COALESCE(SUM(gula_g), 0) AS total_gula,
        COUNT(natrium_mg) AS ada_natrium,
        COALESCE(SUM(natrium_mg), 0) AS total_natrium,
        COUNT(lemak_total_g) AS ada_lemak,
        COALESCE(SUM(lemak_total_g), 0) AS total_lemak
      FROM konsumsi
      WHERE profil_id = ? AND tanggal >= ? AND tanggal <= ?
      GROUP BY tanggal
      ''',
      [profilId, tanggalLokal(mulai), tanggalLokal(akhir)],
    );

    return {
      for (final r in rows)
        r['tanggal'] as String: RingkasanHariTantangan(
          jumlahCatatan: (r['jumlah_catatan'] as num).toInt(),
          adaGula: (r['ada_gula'] as num).toInt(),
          totalGula: (r['total_gula'] as num).toDouble(),
          adaNatrium: (r['ada_natrium'] as num).toInt(),
          totalNatrium: (r['total_natrium'] as num).toDouble(),
          adaLemak: (r['ada_lemak'] as num).toInt(),
          totalLemak: (r['total_lemak'] as num).toDouble(),
        ),
    };
  }

  DateTime _uraiTanggal(String iso) {
    final bagian = iso.split('-');
    return DateTime(int.parse(bagian[0]), int.parse(bagian[1]), int.parse(bagian[2]));
  }
}
