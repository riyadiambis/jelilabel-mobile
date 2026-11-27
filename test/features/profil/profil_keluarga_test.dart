import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/profil/data/profil_repository.dart';
import 'package:jelilabel/features/profil/domain/profil_batas.dart';
import 'package:jelilabel/features/rapor/rapor_cubit.dart';
import 'package:jelilabel/features/tantangan/data/tantangan_repository.dart';
import 'package:jelilabel/features/tantangan/domain/jenis_tantangan.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void _layarSempit(WidgetTester t) {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    await siapkanDependensi(
      lokasiDb: inMemoryDatabasePath,
      jam: () => DateTime(2026, 11, 22, 10),
    );
  });

  tearDown(() async {
    await resetDependensi();
  });

  group('Profil keluarga repository (ISSUE-21 B)', () {
    test('maksimal 5 profil, profil terakhir tidak bisa dihapus, hapus profil menghapus konsumsinya', () async {
      final profilRepo = getIt<ProfilRepository>();
      final asupanRepo = getIt<AsupanRepository>();

      final p1 = await profilRepo.tambahProfil(const ProfilPengguna(nama: 'Dita'));
      final p2 = await profilRepo.tambahProfil(
        const ProfilPengguna(
          nama: 'Ibu',
          umur: KelompokUmur.u50_64,
          jenisKelamin: JenisKelamin.perempuan,
          fokus: FokusZat.natrium,
        ),
      );
      final p3 = await profilRepo.tambahProfil(const ProfilPengguna(nama: 'Raka'));
      final p4 = await profilRepo.tambahProfil(const ProfilPengguna(nama: 'Ayah'));
      final p5 = await profilRepo.tambahProfil(const ProfilPengguna(nama: 'Adik'));

      expect(await profilRepo.bacaDaftarProfil(), hasLength(5));
      await expectLater(
        profilRepo.tambahProfil(const ProfilPengguna(nama: 'Keenam')),
        throwsStateError,
      );

      // Catat konsumsi untuk p1 dan p2
      await profilRepo.pilihProfilAktif(p1.id!);
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Manis', gulaG: 18),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 22, 9),
      );

      await profilRepo.pilihProfilAktif(p2.id!);
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Keripik', natriumMg: 400),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 22, 9),
      );
      expect((await asupanRepo.ringkasanHari(DateTime(2026, 11, 22))).totalNatrium, 400);
      expect((await asupanRepo.ringkasanHari(DateTime(2026, 11, 22))).totalGula, 0);

      // Produk saya dibagi bersama lintas profil
      expect(await asupanRepo.daftarProduk(), hasLength(2));

      // Rapor dan Tantangan memakai profil aktif
      await getIt<TantanganRepository>().mulaiTantangan(
        JenisTantangan.gula5,
        waktuSekarang: DateTime(2026, 11, 22, 8),
      );
      await profilRepo.pilihProfilAktif(p1.id!);
      final raporP1 = getIt<RaporCubit>();
      await raporP1.muat();
      expect(raporP1.state.ringkasan.totalGula, 18);
      await raporP1.close();

      await profilRepo.pilihProfilAktif(p2.id!);
      final raporP2 = getIt<RaporCubit>();
      await raporP2.muat();
      expect(raporP2.state.ringkasan.totalGula, 0);
      expect(raporP2.state.ringkasan.rataNatrium, 400);
      await raporP2.close();

      // Salin data memuat semua profil
      final ekspor = jsonDecode(await asupanRepo.eksporDataJson()) as Map<String, dynamic>;
      expect((ekspor['profil'] as List<dynamic>), hasLength(5));

      // Hapus p2 menghapus konsumsinya juga
      await profilRepo.hapusProfil(p2.id!);
      expect(await asupanRepo.jumlahKonsumsi(), 1);
      expect(await profilRepo.bacaDaftarProfil(), hasLength(4));

      // Hapus hingga tersisa 1 profil -> profil terakhir tidak bisa dihapus
      await profilRepo.hapusProfil(p3.id!);
      await profilRepo.hapusProfil(p4.id!);
      await profilRepo.hapusProfil(p5.id!);
      expect(await profilRepo.bacaDaftarProfil(), hasLength(1));
      await expectLater(profilRepo.hapusProfil(p1.id!), throwsStateError);
    });
  });

  group('UI ganti profil di Beranda dan kelola anggota di Profil (320 px)', () {
    testWidgets('ganti profil di Beranda mengubah sapaan dan ringkasan, lalu hapus profil dari ProfilPage',
        (t) async {
      _layarSempit(t);
      final profilRepo = getIt<ProfilRepository>();
      final asupanRepo = getIt<AsupanRepository>();

      final dita = await profilRepo.tambahProfil(
        const ProfilPengguna(
          nama: 'Dita',
          umur: KelompokUmur.u19_29,
          jenisKelamin: JenisKelamin.perempuan,
          fokus: FokusZat.gula,
        ),
      );
      final ibu = await profilRepo.tambahProfil(
        const ProfilPengguna(
          nama: 'Ibu',
          umur: KelompokUmur.u50_64,
          jenisKelamin: JenisKelamin.perempuan,
          fokus: FokusZat.natrium,
        ),
      );

      await profilRepo.pilihProfilAktif(dita.id!);
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh Dita', gulaG: 18),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 22, 9),
      );

      await profilRepo.pilihProfilAktif(ibu.id!);
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Sup Ibu', natriumMg: 500),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 22, 9),
      );

      await profilRepo.pilihProfilAktif(dita.id!);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      expect(find.text('Hai, Dita!'), findsOneWidget);
      expect(find.text('18 g / 50 g', findRichText: true), findsOneWidget);

      // Ketuk tombol ganti profil di kanan atas -> pilih Ibu
      await t.tap(find.bySemanticsLabel('Ganti profil'));
      await t.pumpAndSettle();
      expect(find.text('Pilih profil'), findsOneWidget);
      await t.tap(find.text('Ibu'));
      await t.pumpAndSettle();

      expect(find.text('Hai, Ibu!'), findsOneWidget);
      expect(find.text('0 g / 45 g', findRichText: true), findsOneWidget);
      expect(find.text('500 mg / 2000 mg', findRichText: true), findsOneWidget);

      // Masuk ke tab Profil -> daftar anggota tampil dan hapus Dita dengan konfirmasi
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profil')));
      await t.pumpAndSettle();

      expect(find.text('50-64 tahun · fokus natrium'), findsOneWidget);
      expect(find.text('19-29 tahun · fokus gula'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);

      await t.tap(find.byTooltip('Hapus Dita'));
      await t.pumpAndSettle();
      expect(find.text('Hapus profil Dita?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await t.pumpAndSettle();

      expect(find.text('Dita'), findsNothing);
      expect(await asupanRepo.jumlahKonsumsi(), 1);
      // Profil terakhir (Ibu) tidak punya tombol hapus
      expect(find.byTooltip('Hapus Ibu'), findsNothing);

      // Tambah anggota baru lewat UI (validasi nama wajib & maks 20)
      await t.tap(find.text('Tambah anggota keluarga'));
      await t.pumpAndSettle();
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      expect(find.text('Isi nama profil'), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'NamaSangatPanjangSekali');
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      expect(find.text('Maksimal 20 huruf'), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'Raka');
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();

      expect(find.text('Raka'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
