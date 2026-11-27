import 'package:sqflite/sqflite.dart';

import '../../asupan/data/asupan_repository.dart' show tanggalLokal;
import '../domain/pengaturan_pengingat.dart';

/// Penyimpanan pengaturan pengingat harian di tabel `pengaturan` dan cek catatan harian di `konsumsi`.
class PengingatRepository {
  PengingatRepository(this._db);

  final Database _db;

  static const kunciAktif = 'pengingat_aktif';
  static const kunciJam = 'pengingat_jam';
  static const kunciMenit = 'pengingat_menit';

  Future<PengaturanPengingat> bacaPengaturan() async {
    final rows = await _db.query(
      'pengaturan',
      columns: ['kunci', 'nilai'],
      where: 'kunci IN (?, ?, ?)',
      whereArgs: [kunciAktif, kunciJam, kunciMenit],
    );
    final peta = {for (final r in rows) r['kunci'] as String: r['nilai'] as String};
    final aktif = peta[kunciAktif] == '1';
    final jamParsed = int.tryParse(peta[kunciJam] ?? '');
    final menitParsed = int.tryParse(peta[kunciMenit] ?? '');
    final jam = (jamParsed != null && jamParsed >= 0 && jamParsed <= 23) ? jamParsed : jamPengingatDefault;
    final menit = (menitParsed != null && menitParsed >= 0 && menitParsed <= 59)
        ? menitParsed
        : menitPengingatDefault;
    return PengaturanPengingat(aktif: aktif, jam: jam, menit: menit);
  }

  Future<void> simpanPengaturan(PengaturanPengingat pengaturan) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'pengaturan',
        {'kunci': kunciAktif, 'nilai': pengaturan.aktif ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'pengaturan',
        {'kunci': kunciJam, 'nilai': '${pengaturan.jam}'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'pengaturan',
        {'kunci': kunciMenit, 'nilai': '${pengaturan.menit}'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<bool> adaCatatanPadaTanggal(DateTime hari) async {
    final rows = await _db.query(
      'konsumsi',
      columns: ['id'],
      where: 'tanggal = ?',
      whereArgs: [tanggalLokal(hari)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
