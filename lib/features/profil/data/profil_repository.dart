import 'package:sqflite/sqflite.dart';

import '../domain/profil_batas.dart';

/// Penyimpanan lokal profil keluarga (maksimal 5) di tabel `profil` dan kunci `pengaturan.profil_aktif`.
class ProfilRepository {
  ProfilRepository(this._db);

  final Database _db;

  static const kunciProfilAktif = 'profil_aktif';

  Future<List<ProfilPengguna>> bacaDaftarProfil() async {
    final rows = await _db.query('profil', orderBy: 'id ASC');
    return rows.map(_dariMap).toList();
  }

  Future<int?> bacaIdProfilAktif() => _bacaIdProfilAktif(_db);

  Future<ProfilPengguna> bacaProfil() async {
    final idAktif = await _bacaIdProfilAktif(_db);
    if (idAktif == null) return ProfilPengguna.kosong;
    final rows = await _db.query('profil', where: 'id = ?', whereArgs: [idAktif], limit: 1);
    if (rows.isEmpty) return ProfilPengguna.kosong;
    return _dariMap(rows.first);
  }

  Future<BatasHarian> bacaBatasAktif() async => (await bacaProfil()).batasHarian;

  /// Memastikan ada minimal satu profil ('Saya') saat akan menambah anggota kedua dari UI.
  Future<ProfilPengguna> pastikanProfilAwal() async {
    return _db.transaction((txn) async {
      final idAktif = await _bacaIdProfilAktif(txn);
      if (idAktif != null) {
        final rows = await txn.query('profil', where: 'id = ?', whereArgs: [idAktif], limit: 1);
        if (rows.isNotEmpty) return _dariMap(rows.first);
      }
      final sekarang = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert('profil', {
        'nama': 'Saya',
        'umur': null,
        'jk': null,
        'fokus': null,
        'batas_gula_g': null,
        'batas_natrium_mg': null,
        'batas_lemak_g': null,
        'dibuat_pada': sekarang,
      });
      await _simpanProfilAktif(txn, id);
      return ProfilPengguna(id: id, nama: 'Saya', dibuatPada: sekarang);
    });
  }

  /// Menyimpan perubahan profil aktif (atau membuat profil pertama bila tabel `profil` masih kosong).
  Future<ProfilPengguna> simpanProfil(ProfilPengguna profil) async {
    final namaBersih = _validasiNama(profil.nama, izinkanDefaultSaya: profil.id == null);
    return _db.transaction((txn) async {
      final targetId = profil.id ?? await _bacaIdProfilAktif(txn);
      if (targetId != null) {
        final updated = await txn.update(
          'profil',
          {
            'nama': namaBersih,
            'umur': profil.umur?.kode,
            'jk': profil.jenisKelamin?.kode,
            'fokus': profil.fokus?.kode,
            'batas_gula_g': _angkaPositif(profil.batasSendiriGulaG),
            'batas_natrium_mg': _angkaPositif(profil.batasSendiriNatriumMg),
            'batas_lemak_g': _angkaPositif(profil.batasSendiriLemakG),
          },
          where: 'id = ?',
          whereArgs: [targetId],
        );
        if (updated > 0) {
          await _simpanProfilAktif(txn, targetId);
          final rows = await txn.query('profil', where: 'id = ?', whereArgs: [targetId], limit: 1);
          return _dariMap(rows.first);
        }
      }

      final jumlah = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM profil')) ?? 0;
      if (jumlah >= maksProfilKeluarga) {
        throw StateError('Maksimal $maksProfilKeluarga profil.');
      }

      final sekarang = DateTime.now().millisecondsSinceEpoch;
      final idBaru = await txn.insert('profil', {
        'nama': namaBersih,
        'umur': profil.umur?.kode,
        'jk': profil.jenisKelamin?.kode,
        'fokus': profil.fokus?.kode,
        'batas_gula_g': _angkaPositif(profil.batasSendiriGulaG),
        'batas_natrium_mg': _angkaPositif(profil.batasSendiriNatriumMg),
        'batas_lemak_g': _angkaPositif(profil.batasSendiriLemakG),
        'dibuat_pada': sekarang,
      });
      await _simpanProfilAktif(txn, idBaru);
      final rows = await txn.query('profil', where: 'id = ?', whereArgs: [idBaru], limit: 1);
      return _dariMap(rows.first);
    });
  }

  /// Menambahkan profil anggota keluarga baru (maksimal 5 profil).
  Future<ProfilPengguna> tambahProfil(ProfilPengguna profil) async {
    final namaBersih = _validasiNama(profil.nama);
    return _db.transaction((txn) async {
      final jumlah = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM profil')) ?? 0;
      if (jumlah >= maksProfilKeluarga) {
        throw StateError('Maksimal $maksProfilKeluarga profil.');
      }
      final sekarang = DateTime.now().millisecondsSinceEpoch;
      final idBaru = await txn.insert('profil', {
        'nama': namaBersih,
        'umur': profil.umur?.kode,
        'jk': profil.jenisKelamin?.kode,
        'fokus': profil.fokus?.kode,
        'batas_gula_g': _angkaPositif(profil.batasSendiriGulaG),
        'batas_natrium_mg': _angkaPositif(profil.batasSendiriNatriumMg),
        'batas_lemak_g': _angkaPositif(profil.batasSendiriLemakG),
        'dibuat_pada': sekarang,
      });
      final aktifSebelumnya = await _bacaIdProfilAktif(txn);
      if (aktifSebelumnya == null) {
        await _simpanProfilAktif(txn, idBaru);
      }
      final rows = await txn.query('profil', where: 'id = ?', whereArgs: [idBaru], limit: 1);
      return _dariMap(rows.first);
    });
  }

  Future<void> pilihProfilAktif(int profilId) async {
    await _db.transaction((txn) async {
      final ada = await txn.query('profil', columns: ['id'], where: 'id = ?', whereArgs: [profilId], limit: 1);
      if (ada.isEmpty) {
        throw StateError('Profil #$profilId tidak ditemukan.');
      }
      await _simpanProfilAktif(txn, profilId);
    });
  }

  /// Menghapus profil beserta seluruh catatan konsumsinya. Profil terakhir tidak bisa dihapus.
  Future<void> hapusProfil(int profilId) async {
    await _db.transaction((txn) async {
      final jumlah = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM profil')) ?? 0;
      if (jumlah <= 1) {
        throw StateError('Profil terakhir tidak bisa dihapus.');
      }
      final ada = await txn.query('profil', columns: ['id'], where: 'id = ?', whereArgs: [profilId], limit: 1);
      if (ada.isEmpty) {
        throw StateError('Profil #$profilId tidak ditemukan.');
      }
      await txn.delete('konsumsi', where: 'profil_id = ?', whereArgs: [profilId]);
      await txn.delete('profil', where: 'id = ?', whereArgs: [profilId]);

      final rowsAktif = await txn.query(
        'pengaturan',
        columns: ['nilai'],
        where: 'kunci = ?',
        whereArgs: [kunciProfilAktif],
        limit: 1,
      );
      final aktifId = rowsAktif.isEmpty ? null : int.tryParse(rowsAktif.first['nilai'] as String? ?? '');
      if (aktifId == null || aktifId == profilId) {
        final sisa = await txn.query('profil', columns: ['id'], orderBy: 'id ASC', limit: 1);
        if (sisa.isNotEmpty) {
          await _simpanProfilAktif(txn, (sisa.first['id'] as num).toInt());
        }
      }
    });
  }

  static Future<int?> _bacaIdProfilAktif(DatabaseExecutor db) async {
    final rows = await db.query(
      'pengaturan',
      columns: ['nilai'],
      where: 'kunci = ?',
      whereArgs: [kunciProfilAktif],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final id = int.tryParse(rows.first['nilai'] as String? ?? '');
      if (id != null) {
        final ada = await db.query('profil', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
        if (ada.isNotEmpty) return id;
      }
    }
    final pertama = await db.query('profil', columns: ['id'], orderBy: 'id ASC', limit: 1);
    if (pertama.isEmpty) return null;
    return (pertama.first['id'] as num).toInt();
  }

  static Future<void> _simpanProfilAktif(Transaction txn, int profilId) => txn.insert(
        'pengaturan',
        {'kunci': kunciProfilAktif, 'nilai': '$profilId'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  static String _validasiNama(String nama, {bool izinkanDefaultSaya = false}) {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      if (izinkanDefaultSaya) return 'Saya';
      throw ArgumentError.value(nama, 'nama', 'Nama profil wajib diisi.');
    }
    if (bersih.length > maksPanjangNamaProfil) {
      throw ArgumentError.value(nama, 'nama', 'Nama profil maksimal $maksPanjangNamaProfil huruf.');
    }
    return bersih;
  }

  static double? _angkaPositif(double? v) => (v != null && v.isFinite && v > 0) ? v : null;

  static ProfilPengguna _dariMap(Map<String, Object?> r) => ProfilPengguna(
        id: (r['id'] as num).toInt(),
        nama: r['nama'] as String,
        umur: KelompokUmur.dariKode(r['umur'] as String?),
        jenisKelamin: JenisKelamin.dariKode(r['jk'] as String?),
        fokus: FokusZat.dariKode(r['fokus'] as String?),
        batasSendiriGulaG: _angkaPositif((r['batas_gula_g'] as num?)?.toDouble()),
        batasSendiriNatriumMg: _angkaPositif((r['batas_natrium_mg'] as num?)?.toDouble()),
        batasSendiriLemakG: _angkaPositif((r['batas_lemak_g'] as num?)?.toDouble()),
        dibuatPada: (r['dibuat_pada'] as num?)?.toInt(),
      );
}
