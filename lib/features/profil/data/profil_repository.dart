import 'package:sqflite/sqflite.dart';

import '../domain/profil_batas.dart';

/// Penyimpanan lokal profil singkat dan batas pribadi di tabel `pengaturan`.
class ProfilRepository {
  ProfilRepository(this._db);

  final Database _db;

  static const kunciUmur = 'profil_umur';
  static const kunciJenisKelamin = 'profil_jk';
  static const kunciFokus = 'profil_fokus';
  static const kunciBatasSendiriGula = 'batas_sendiri_gula_g';
  static const kunciBatasSendiriNatrium = 'batas_sendiri_natrium_mg';
  static const kunciBatasSendiriLemak = 'batas_sendiri_lemak_g';

  static const semuaKunciProfil = [
    kunciUmur,
    kunciJenisKelamin,
    kunciFokus,
    kunciBatasSendiriGula,
    kunciBatasSendiriNatrium,
    kunciBatasSendiriLemak,
  ];

  Future<ProfilPengguna> bacaProfil() async {
    final rows = await _db.query(
      'pengaturan',
      columns: ['kunci', 'nilai'],
      where: 'kunci IN (?, ?, ?, ?, ?, ?)',
      whereArgs: semuaKunciProfil,
    );
    final peta = {for (final r in rows) r['kunci'] as String: r['nilai'] as String};
    return ProfilPengguna(
      umur: KelompokUmur.dariKode(peta[kunciUmur]),
      jenisKelamin: JenisKelamin.dariKode(peta[kunciJenisKelamin]),
      fokus: FokusZat.dariKode(peta[kunciFokus]),
      batasSendiriGulaG: _uraiPositif(peta[kunciBatasSendiriGula]),
      batasSendiriNatriumMg: _uraiPositif(peta[kunciBatasSendiriNatrium]),
      batasSendiriLemakG: _uraiPositif(peta[kunciBatasSendiriLemak]),
    );
  }

  Future<BatasHarian> bacaBatasAktif() async => (await bacaProfil()).batasHarian;

  Future<void> simpanProfil(ProfilPengguna profil) async {
    await _db.transaction((txn) async {
      await _simpanAtauHapus(txn, kunciUmur, profil.umur?.kode);
      await _simpanAtauHapus(txn, kunciJenisKelamin, profil.jenisKelamin?.kode);
      await _simpanAtauHapus(txn, kunciFokus, profil.fokus?.kode);
      await _simpanAtauHapus(
        txn,
        kunciBatasSendiriGula,
        _formatAngkaPositif(profil.batasSendiriGulaG),
      );
      await _simpanAtauHapus(
        txn,
        kunciBatasSendiriNatrium,
        _formatAngkaPositif(profil.batasSendiriNatriumMg),
      );
      await _simpanAtauHapus(
        txn,
        kunciBatasSendiriLemak,
        _formatAngkaPositif(profil.batasSendiriLemakG),
      );
    });
  }

  Future<void> hapusProfil() async {
    await _db.delete(
      'pengaturan',
      where: 'kunci IN (?, ?, ?, ?, ?, ?)',
      whereArgs: semuaKunciProfil,
    );
  }

  static Future<void> _simpanAtauHapus(Transaction txn, String kunci, String? nilai) async {
    if (nilai == null) {
      await txn.delete('pengaturan', where: 'kunci = ?', whereArgs: [kunci]);
      return;
    }
    await txn.insert(
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static double? _uraiPositif(String? raw) {
    if (raw == null) return null;
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v <= 0) return null;
    return v;
  }

  static String? _formatAngkaPositif(double? v) {
    if (v == null || !v.isFinite || v <= 0) return null;
    return v.roundToDouble() == v ? v.toStringAsFixed(0) : v.toString();
  }
}
