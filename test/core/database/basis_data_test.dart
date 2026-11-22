import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BasisData skema v2 dan batasan', () {
    late BasisData basis;

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
    });

    tearDown(() async {
      await basis.tutup();
    });

    test('membuat tabel produk, konsumsi, pengaturan, indeks, dan user_version = 2', () async {
      final master = await basis.db.rawQuery(
        "SELECT type, name FROM sqlite_master WHERE name IN ('produk', 'konsumsi', 'pengaturan', 'idx_konsumsi_tanggal')",
      );
      final namaObjek = {for (final r in master) r['name'] as String: r['type'] as String};
      expect(namaObjek['produk'], 'table');
      expect(namaObjek['konsumsi'], 'table');
      expect(namaObjek['pengaturan'], 'table');
      expect(namaObjek['idx_konsumsi_tanggal'], 'index');

      final infoKonsumsi = await basis.db.rawQuery('PRAGMA table_info(konsumsi)');
      final kolomKonsumsi = {for (final r in infoKonsumsi) r['name'] as String};
      expect(kolomKonsumsi, contains('lemak_total_g'));

      final versi = await basis.db.rawQuery('PRAGMA user_version');
      expect(versi.single.values.single, 2);
    });

    test('PRAGMA foreign_keys = ON aktif pada koneksi', () async {
      final fk = await basis.db.rawQuery('PRAGMA foreign_keys');
      expect(fk.single.values.single, 1);
    });

    test('CHECK jumlah_sajian > 0 menolak 0 dan nilai negatif', () async {
      final produkId = await basis.db.insert('produk', {
        'nama': 'Teh Botol',
        'gula_g': 20,
        'natrium_mg': 10,
        'sumber': 'pindai',
        'dibuat_pada': 1000,
      });

      await expectLater(
        basis.db.insert('konsumsi', {
          'produk_id': produkId,
          'jumlah_sajian': 0,
          'gula_g': 0,
          'natrium_mg': 0,
          'tanggal': '2026-11-20',
          'dibuat_pada': 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        basis.db.insert('konsumsi', {
          'produk_id': produkId,
          'jumlah_sajian': -1,
          'gula_g': -20,
          'natrium_mg': -10,
          'tanggal': '2026-11-20',
          'dibuat_pada': 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('CHECK produk menolak sumber tidak sah, gula negatif, natrium negatif, dan satuan tidak sah', () async {
      await expectLater(
        basis.db.insert('produk', {
          'nama': 'X',
          'sumber': 'lain',
          'dibuat_pada': 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        basis.db.insert('produk', {
          'nama': 'X',
          'gula_g': -1,
          'sumber': 'manual',
          'dibuat_pada': 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        basis.db.insert('produk', {
          'nama': 'X',
          'natrium_mg': -0.5,
          'sumber': 'manual',
          'dibuat_pada': 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        basis.db.insert('produk', {
          'nama': 'X',
          'takaran_saji_satuan': 'kg',
          'sumber': 'manual',
          'dibuat_pada': 1000,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('ON DELETE RESTRICT menolak hapus produk yang masih dirujuk konsumsi', () async {
      final produkId = await basis.db.insert('produk', {
        'nama': 'Susu Cokelat',
        'gula_g': 12,
        'natrium_mg': 95,
        'sumber': 'pindai',
        'dibuat_pada': 1000,
      });
      final konsumsiId = await basis.db.insert('konsumsi', {
        'produk_id': produkId,
        'jumlah_sajian': 1,
        'gula_g': 12,
        'natrium_mg': 95,
        'tanggal': '2026-11-20',
        'dibuat_pada': 1000,
      });

      await expectLater(
        basis.db.delete('produk', where: 'id = ?', whereArgs: [produkId]),
        throwsA(isA<DatabaseException>()),
      );

      // Hapus konsumsi tidak menghapus produk
      await basis.db.delete('konsumsi', where: 'id = ?', whereArgs: [konsumsiId]);
      final produk = await basis.db.query('produk', where: 'id = ?', whereArgs: [produkId]);
      expect(produk, hasLength(1));
    });

    test('snapshot konsumsi tidak berubah saat data produk disunting', () async {
      final produkId = await basis.db.insert('produk', {
        'nama': 'Susu',
        'gula_g': 12,
        'natrium_mg': 95,
        'sumber': 'pindai',
        'dibuat_pada': 1000,
      });
      final konsumsiId = await basis.db.insert('konsumsi', {
        'produk_id': produkId,
        'jumlah_sajian': 0.5,
        'gula_g': 6,
        'natrium_mg': 47.5,
        'tanggal': '2026-11-20',
        'dibuat_pada': 1000,
      });

      await basis.db.update('produk', {'gula_g': 99}, where: 'id = ?', whereArgs: [produkId]);
      final baris = await basis.db.query('konsumsi', where: 'id = ?', whereArgs: [konsumsiId]);
      expect(baris.single['gula_g'], 6.0);
    });
  });

  test('pengaturan perkenalan_selesai dan peringatan bertahan setelah berkas DB ditutup dan dibuka lagi', () async {
    final dir = await Directory.systemTemp.createTemp('jelilabel_db_test_');
    final path = join(dir.path, 'uji.db');
    try {
      final b1 = await BasisData.buka(lokasiDb: path);
      await b1.db.insert('pengaturan', {'kunci': 'perkenalan_selesai', 'nilai': '1'});
      await b1.db.insert('pengaturan', {'kunci': 'peringatan_gula_tanggal', 'nilai': '2026-11-20'});
      await b1.tutup();

      final b2 = await BasisData.buka(lokasiDb: path);
      final rows = await b2.db.query('pengaturan');
      final map = {for (final r in rows) r['kunci'] as String: r['nilai'] as String};
      expect(map['perkenalan_selesai'], '1');
      expect(map['peringatan_gula_tanggal'], '2026-11-20');
      await b2.tutup();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('migrasi v1 ke v2 menambah konsumsi.lemak_total_g dan mempertahankan baris lama', () async {
    final dir = await Directory.systemTemp.createTemp('jelilabel_migrasi_v1_v2_');
    final path = join(dir.path, 'migrasi.db');
    try {
      final dbV1 = await openDatabase(
        path,
        version: 1,
        singleInstance: false,
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
    tanggal         TEXT    NOT NULL,
    dibuat_pada     INTEGER NOT NULL,
    CHECK (jumlah_sajian > 0)
)''');
          await db.execute('CREATE INDEX idx_konsumsi_tanggal ON konsumsi(tanggal)');
          await db.execute('CREATE TABLE pengaturan (kunci TEXT PRIMARY KEY, nilai TEXT NOT NULL)');
        },
      );
      final produkId = await dbV1.insert('produk', {
        'nama': 'Teh Botol Lama',
        'gula_g': 18,
        'natrium_mg': 25,
        'sumber': 'pindai',
        'dibuat_pada': 1700000000000,
      });
      await dbV1.insert('konsumsi', {
        'produk_id': produkId,
        'jumlah_sajian': 1,
        'gula_g': 18,
        'natrium_mg': 25,
        'tanggal': '2026-11-19',
        'dibuat_pada': 1700000000000,
      });
      await dbV1.insert('pengaturan', {'kunci': 'perkenalan_selesai', 'nilai': '1'});
      await dbV1.close();

      final basisV2 = await BasisData.buka(lokasiDb: path);
      final versi = await basisV2.db.rawQuery('PRAGMA user_version');
      expect(versi.single.values.single, 2);

      final barisLama = await basisV2.db.query('konsumsi');
      expect(barisLama, hasLength(1));
      expect(barisLama.single['gula_g'], 18.0);
      expect(barisLama.single['natrium_mg'], 25.0);
      expect(barisLama.single['lemak_total_g'], isNull);
      expect(barisLama.single['tanggal'], '2026-11-19');

      final idBaru = await basisV2.db.insert('konsumsi', {
        'produk_id': produkId,
        'jumlah_sajian': 1,
        'gula_g': 18,
        'natrium_mg': 25,
        'lemak_total_g': 6.7,
        'tanggal': '2026-11-23',
        'dibuat_pada': 1700000001000,
      });
      expect(idBaru, greaterThan(1));
      await basisV2.tutup();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
