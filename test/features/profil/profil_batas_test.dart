import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/bagikan/data_kartu_bagikan.dart';
import 'package:jelilabel/features/profil/data/profil_repository.dart';
import 'package:jelilabel/features/profil/domain/profil_batas.dart';
import 'package:jelilabel/features/profil/presentation/profil_cubit.dart';
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
      jam: () => DateTime(2026, 11, 19, 10),
    );
  });

  tearDown(() async {
    await resetDependensi();
  });

  group('ProfilRepository dan integrasi batas di Rapor/Tantangan/Bagikan/Ekspor', () {
    test('simpan, baca, hapus batas sendiri, ekspor JSON/CSV, dan resetSemuaData', () async {
      final profilRepo = getIt<ProfilRepository>();
      final asupanRepo = getIt<AsupanRepository>();

      expect(await profilRepo.bacaBatasAktif(), BatasHarian.kemenkes);

      await profilRepo.simpanProfil(
        const ProfilPengguna(
          umur: KelompokUmur.u50_64,
          jenisKelamin: JenisKelamin.perempuan,
          fokus: FokusZat.natrium,
          batasSendiriGulaG: 30,
        ),
      );
      final terbaca = await profilRepo.bacaProfil();
      expect(terbaca.umur, KelompokUmur.u50_64);
      expect(terbaca.jenisKelamin, JenisKelamin.perempuan);
      expect(terbaca.fokus, FokusZat.natrium);
      expect(terbaca.batasSendiriGulaG, 30);
      expect(terbaca.batasHarian.gulaG, 30);
      expect(terbaca.batasHarian.sumber, SumberBatas.dariDokter);

      final jsonStr = await asupanRepo.eksporDataJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pengaturan = decoded['pengaturan'] as Map<String, dynamic>;
      final daftarProfil = decoded['profil'] as List<dynamic>;
      expect(daftarProfil, hasLength(1));
      final profilJson = daftarProfil.single as Map<String, dynamic>;
      expect(profilJson['nama'], 'Saya');
      expect(profilJson['umur'], '50-64');
      expect(profilJson['jk'], 'P');
      expect(profilJson['fokus'], 'natrium');
      expect(profilJson['batas_gula_g'], 30.0);
      expect(pengaturan['profil_aktif'], '${profilJson['id']}');

      final csv = await asupanRepo.eksporDataCsv();
      expect(csv, contains('profil,1,,Saya,'));
      expect(csv, contains(',50-64,P,natrium,30.0,'));

      // Ubah ke non-dokter -> batas_gula_g di tabel profil terhapus
      await profilRepo.simpanProfil(
        const ProfilPengguna(
          umur: KelompokUmur.u50_64,
          jenisKelamin: JenisKelamin.perempuan,
          fokus: FokusZat.gula,
        ),
      );
      expect((await profilRepo.bacaProfil()).batasSendiriGulaG, isNull);
      expect((await profilRepo.bacaBatasAktif()).gulaG, 45);
      expect((await profilRepo.bacaBatasAktif()).sumber, SumberBatas.pribadi);

      // Hapus semua data menghapus seluruh profil dan mengembalikan batas ke Kemenkes
      await asupanRepo.hapusSemuaData();
      expect(await profilRepo.bacaDaftarProfil(), isEmpty);
      expect(await profilRepo.bacaProfil(), ProfilPengguna.kosong);
      expect(await profilRepo.bacaBatasAktif(), BatasHarian.kemenkes);
    });

    test('RaporCubit, TantanganRepository, dan DataKartuBagikan memakai batas pribadi aktif', () async {
      final profilRepo = getIt<ProfilRepository>();
      final asupanRepo = getIt<AsupanRepository>();
      final tantanganRepo = getIt<TantanganRepository>();

      // P 80+ -> batas gula 35 g
      await profilRepo.simpanProfil(
        const ProfilPengguna(
          umur: KelompokUmur.u80Plus,
          jenisKelamin: JenisKelamin.perempuan,
        ),
      );

      // Catat 40 g gula (di bawah Kemenkes 50 g, tapi lewat batas pribadi 35 g)
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Minuman Manis', gulaG: 40),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 19, 9),
      );

      final raporCubit = getIt<RaporCubit>();
      await raporCubit.muat();
      expect(raporCubit.state.ringkasan.hariAdaCatatan, 1);
      expect(raporCubit.state.ringkasan.hariGulaDiBawahBatas, 0);
      await raporCubit.close();

      await tantanganRepo.mulaiTantangan(JenisTantangan.gula5, waktuSekarang: DateTime(2026, 11, 19, 8));
      final batas = await profilRepo.bacaBatasAktif();
      final statusTantangan = await tantanganRepo.bacaStatus(
        waktuSekarang: DateTime(2026, 11, 19, 12),
        batas: batas,
      );
      expect(statusTantangan.berjalan?.jumlahBerhasil, 0);

      final infoBagikan = DataKartuBagikan(
        namaProduk: 'Teh',
        labelPorsi: '1 sajian',
        gulaG: 17.5,
        batas: batas,
      ).info;
      expect(infoBagikan.teksPersen, '50% dari batas gula harian (35 g)');
    });
  });

  group('UI ProfilBatasPage dan dampaknya di Beranda, CekHasil, Tentang, Profil', () {
    testWidgets('layar /profil/batas menampilkan 7 chip AKG, tanpa di bawah 13, teks usia 13+, dan bisa dilewati',
        (t) async {
      _layarSempit(t);
      await t.pumpWidget(JeliLabelApp(awal: '/profil/batas?awal=1'));
      await t.pumpAndSettle();

      for (final u in ['13-15', '16-18', '19-29', '30-49', '50-64', '65-80', '80+']) {
        expect(find.text(u), findsOneWidget);
      }
      expect(find.textContaining('di bawah 13', findRichText: true), findsNothing);
      expect(find.text('JeliLabel untuk usia 13 tahun ke atas.'), findsOneWidget);
      expect(
        find.text('Batas gula dihitung dari tabel AKG Kemenkes untuk usiamu, paling tinggi 50 g.'),
        findsOneWidget,
      );
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Nanti saja'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.tap(find.text('Nanti saja'));
      await t.pumpAndSettle();
      expect(find.text('Belum ada catatan hari ini'), findsOneWidget);
      expect(find.text('0 g / 50 g', findRichText: true), findsOneWidget);
      expect(find.textContaining('Acuan Kemenkes:'), findsNothing);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('simpan P 50-64 fokus Natrium mengatur urutan Beranda, acuan 50 g, CekHasil, Tentang, dan Hapus data',
        (t) async {
      _layarSempit(t);
      await t.pumpWidget(JeliLabelApp(awal: '/profil'));
      await t.pumpAndSettle();

      await t.tap(find.text('Batas harian'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('50-64'));
      await t.pumpAndSettle();
      await t.tap(find.text('50-64'));
      await t.ensureVisible(find.text('Perempuan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Perempuan'));
      await t.ensureVisible(find.text('Natrium').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Natrium').first);
      await t.pumpAndSettle();

      // Pratinjau menunjukkan 45 g dan Acuan Kemenkes: 50 g
      await t.ensureVisible(find.text('45 g'));
      await t.pumpAndSettle();
      expect(find.text('45 g'), findsOneWidget);
      expect(find.text('Acuan Kemenkes: 50 g'), findsOneWidget);

      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();

      // Kembali ke Profil -> nilai menu berubah menjadi Pribadi
      expect(find.text('Pribadi'), findsOneWidget);

      // Cek Tentang -> tampil Acuan Kemenkes: 50 g
      await t.ensureVisible(find.text('Tentang dan privasi'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tentang dan privasi'));
      await t.pumpAndSettle();
      expect(find.text('Batas harian aktif (Pribadi)'), findsOneWidget);
      expect(find.text('Gula: 45 g'), findsOneWidget);
      expect(find.text('Acuan Kemenkes: 50 g'), findsOneWidget);
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();

      // Ke Beranda -> Natrium tampil di atas Gula, batas gula 45 g + Acuan Kemenkes: 50 g
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Beranda')));
      await t.pumpAndSettle();
      expect(find.text('0 g / 45 g', findRichText: true), findsOneWidget);
      expect(find.text('Acuan Kemenkes: 50 g'), findsOneWidget);

      final yNatrium = t.getTopLeft(find.text('Natrium')).dy;
      final yGula = t.getTopLeft(find.text('Gula')).dy;
      final yLemak = t.getTopLeft(find.text('Lemak')).dy;
      expect(yNatrium, lessThan(yGula));
      expect(yGula, lessThan(yLemak));

      // CekHasilPage: 12 g gula (27% dari 45 g) -> Tinggi (bukan Waspada)
      await t.ensureVisible(find.text('Pindai Label Gizi'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pindai Label Gizi'));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(find.text('Tinggi, karena gulanya'), findsOneWidget);
      expect(find.text('27% jatah harian', findRichText: true), findsOneWidget);

      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();

      // Sapaan Beranda tetap status terburuk (jika ada yang hampir/lewat batas)
      // Di sini 12 g / 45 g aman (<75%), 95 mg / 2000 mg aman -> 'Hari ini masih aman'.
      expect(find.text('Hari ini masih aman'), findsOneWidget);

      // Tambah gula tinggi lewat isi manual agar gula lewat batas sementara natrium fokus masih aman -> sapaan tetap terburuk
      await t.ensureVisible(find.text('Isi manual'));
      await t.pumpAndSettle();
      await t.tap(find.text('Isi manual'));
      await t.pumpAndSettle();
      final isian = find.byType(TextField);
      await t.enterText(isian.at(0), 'Sirup');
      await t.enterText(isian.at(1), '35');
      await t.pump();
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Gula sudah lewat batas'));
      await t.pumpAndSettle();
      expect(find.text('Gula sudah lewat batas'), findsOneWidget);

      // Profil -> batas sendiri (Dari dokter)
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profil')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Batas harian'));
      await t.pumpAndSettle();
      await t.tap(find.text('Batas harian'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Ya, isi sendiri'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ya, isi sendiri'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(TextField).at(1));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(1), '25');
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Dari dokter'));
      await t.pumpAndSettle();
      expect(find.text('Dari dokter'), findsOneWidget);
      expect(find.text('25 g'), findsOneWidget);
      await t.tap(find.text('Simpan'));
      await t.pumpAndSettle();
      expect(find.text('Dari dokter'), findsOneWidget);

      // Hapus semua data -> profil terhapus dan ProfilCubit kembali ke Kemenkes
      await t.ensureVisible(find.text('Hapus semua data'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hapus semua data'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'HAPUS');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await t.pumpAndSettle();

      expect(find.text('Hai, aku Nuri!'), findsOneWidget);
      expect(await getIt<ProfilRepository>().bacaProfil(), ProfilPengguna.kosong);
      final elemen = t.element(find.byType(MaterialApp));
      expect(elemen.read<ProfilCubit>().state.batas, BatasHarian.kemenkes);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
