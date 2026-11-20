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

  group('BasisData skema v1 dan batasan', () {
    late BasisData basis;

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
    });

    tearDown(() async {
      await basis.tutup();
    });

    test('membuat tabel produk, konsumsi, pengaturan, indeks, dan user_version = 1', () async {
      final master = await basis.db.rawQuery(
        "SELECT type, name FROM sqlite_master WHERE name IN ('produk', 'konsumsi', 'pengaturan', 'idx_konsumsi_tanggal')",
      );
      final namaObjek = {for (final r in master) r['name'] as String: r['type'] as String};
      expect(namaObjek['produk'], 'table');
      expect(namaObjek['konsumsi'], 'table');
      expect(namaObjek['pengaturan'], 'table');
      expect(namaObjek['idx_konsumsi_tanggal'], 'index');

      final versi = await basis.db.rawQuery('PRAGMA user_version');
      expect(versi.single.values.single, 1);
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
}
