import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

/// Pembungkus koneksi SQLite lokal sesuai docs/SCHEMA.sql versi 2.
class BasisData {
  BasisData._(this.db);

  final Database db;

  static Future<BasisData> buka({String? lokasiDb}) async {
    final lokasi = lokasiDb ?? join(await getDatabasesPath(), 'jelilabel.db');
    final db = await openDatabase(
      lokasi,
      version: 2,
      singleInstance: lokasiDb != inMemoryDatabasePath,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE produk (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nama                TEXT    NOT NULL,
    takaran_saji_jumlah REAL,
    takaran_saji_satuan TEXT,
    sajian_per_kemasan  REAL,
    gula_g              REAL,
    natrium_mg          REAL,
    energi_kkal         REAL,
    lemak_total_g       REAL,
    protein_g           REAL,
    karbohidrat_g       REAL,
    sumber              TEXT    NOT NULL,
    dibuat_pada         INTEGER NOT NULL,

    CHECK (takaran_saji_satuan IN ('g','ml') OR takaran_saji_satuan IS NULL),
    CHECK (sumber IN ('pindai','manual','dataset')),
    CHECK (gula_g IS NULL OR gula_g >= 0),
    CHECK (natrium_mg IS NULL OR natrium_mg >= 0)
)''');

        await db.execute('''
CREATE TABLE konsumsi (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    produk_id       INTEGER NOT NULL REFERENCES produk(id) ON DELETE RESTRICT,
    jumlah_sajian   REAL    NOT NULL,
    gula_g          REAL,
    natrium_mg      REAL,
    lemak_total_g   REAL,
    tanggal         TEXT    NOT NULL,
    dibuat_pada     INTEGER NOT NULL,

    CHECK (jumlah_sajian > 0)
)''');

        await db.execute('CREATE INDEX idx_konsumsi_tanggal ON konsumsi(tanggal)');

        await db.execute('''
CREATE TABLE pengaturan (
    kunci   TEXT PRIMARY KEY,
    nilai   TEXT NOT NULL
)''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE konsumsi ADD COLUMN lemak_total_g REAL');
        }
      },
    );
    return BasisData._(db);
  }

  Future<void> tutup() => db.close();
}
