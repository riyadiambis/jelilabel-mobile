import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/core/di/injeksi.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/tantangan/data/tantangan_repository.dart';
import 'package:jelilabel/features/tantangan/domain/jenis_tantangan.dart';
import 'package:jelilabel/features/tantangan/presentation/tantangan_cubit.dart';
import 'package:jelilabel/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('TantanganRepository & domain logika kemajuan', () {
    late BasisData basis;
    late AsupanRepository asupanRepo;
    late TantanganRepository tantanganRepo;
    late DateTime sekarang;

    setUp(() async {
      sekarang = DateTime(2026, 11, 16, 10, 0); // Senin 16 Nov 2026
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      asupanRepo = AsupanRepository(basis.db);
      tantanganRepo = TantanganRepository(basis.db);
    });

    tearDown(() async {
      await basis.tutup();
    });

    test('gula_5: batas tepi 50 g, hari NULL tidak dihitung, hari kosong tidak gagal, selesai di hari ke-5', () async {
      await tantanganRepo.mulaiTantangan(JenisTantangan.gula5, waktuSekarang: sekarang);

      // Hari 0 (16 Nov): tepat 50 g -> berhasil
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Sirup', gulaG: 50),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 16, 9),
      );
      // Hari 1 (17 Nov): 50.1 g -> tidak berhasil
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Boba', gulaG: 50.1),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 17, 9),
      );
      // Hari 2 (18 Nov): gula NULL (hanya ada natrium) -> tidak dihitung berhasil
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Keripik', gulaG: null, natriumMg: 100),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 18, 9),
      );
      // Hari 3 (19 Nov): kosong -> tidak dihitung berhasil dan tidak gagal
      // Hari 4 (20 Nov): 2 item total 40 g -> berhasil
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 8),
      );
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Roti', gulaG: 20),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 20, 12),
      );

      sekarang = DateTime(2026, 11, 20, 18);
      final tengah = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(tengah.berjalan, isNotNull);
      expect(tengah.berjalan!.jumlahBerhasil, 2);
      expect(tengah.berjalan!.terpenuhi, 2);
      expect(tengah.berjalan!.sisaHari, 2); // 21, 22 Nov
      expect(tengah.berjalan!.tujuhHari[0].status, StatusHariTantangan.berhasil);
      expect(tengah.berjalan!.tujuhHari[1].status, StatusHariTantangan.belum);
      expect(tengah.berjalan!.tujuhHari[2].status, StatusHariTantangan.belum);
      expect(tengah.berjalan!.tujuhHari[3].status, StatusHariTantangan.belum);
      expect(tengah.berjalan!.tujuhHari[4].status, StatusHariTantangan.berhasil);
      expect(tengah.berjalan!.tujuhHari[5].status, StatusHariTantangan.mendatang);
      expect(tengah.berjalan!.tujuhHari[6].status, StatusHariTantangan.mendatang);
      expect(tengah.lencana, isEmpty);

      // Tambah 3 hari berhasil tidak bisa di jendela ini karena tersisa 2 hari (21, 22),
      // tapi mari uji tercapai tepat pada tantangan baru yang mulai 16 Nov setelah reset:
      // Untuk uji tercapai, perbarui hari 18 & 19 & 21 menjadi <= 50 g:
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 10),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 18, 12),
      );
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 15),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 19, 12),
      );
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 50),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 21, 12),
      );

      sekarang = DateTime(2026, 11, 21, 15);
      final selesai = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(selesai.berjalan, isNull);
      expect(selesai.lencana, hasLength(1));
      expect(selesai.lencana.single.jenis, JenisTantangan.gula5);
      expect(selesai.lencana.single.selesaiPada, sekarang.millisecondsSinceEpoch);
      expect(selesai.ucapanTercapai?.id, selesai.lencana.single.id);
    });

    test('natrium_5 dan lemak_5: batas tepi 2000 mg dan 67 g serta nilai NULL diabaikan', () async {
      // Natrium 5 hari
      await tantanganRepo.mulaiTantangan(JenisTantangan.natrium5, waktuSekarang: sekarang);
      // 16 Nov: NULL natrium -> tidak lulus
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Gula Pasir', gulaG: 10, natriumMg: null),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 16, 9),
      );
      // 17 Nov: 2000.1 mg -> tidak lulus
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Mi', natriumMg: 2000.1),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 17, 9),
      );
      // 18..22 Nov (5 hari): tepat 2000 mg -> lulus
      for (var d = 18; d <= 22; d++) {
        await asupanRepo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Sup', natriumMg: 2000),
          jumlahSajian: 1,
          waktuLokal: DateTime(2026, 11, d, 9),
        );
      }
      sekarang = DateTime(2026, 11, 22, 12);
      final hasilNatrium = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(hasilNatrium.berjalan, isNull);
      expect(hasilNatrium.lencana.single.jenis, JenisTantangan.natrium5);

      // Lemak 5 hari dimulai 23 Nov
      sekarang = DateTime(2026, 11, 23, 8);
      await tantanganRepo.mulaiTantangan(JenisTantangan.lemak5, waktuSekarang: sekarang);
      // 23 Nov: NULL lemak -> tidak lulus
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Teh', gulaG: 5, lemakTotalG: null),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 23, 9),
      );
      // 24 Nov: 67.1 g -> tidak lulus
      await asupanRepo.simpanKonsumsi(
        draf: const DrafProduk(nama: 'Gorengan', lemakTotalG: 67.1),
        jumlahSajian: 1,
        waktuLokal: DateTime(2026, 11, 24, 9),
      );
      // 25..29 Nov (5 hari): tepat 67 g -> lulus
      for (var d = 25; d <= 29; d++) {
        await asupanRepo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Kacang', lemakTotalG: 67),
          jumlahSajian: 1,
          waktuLokal: DateTime(2026, 11, d, 9),
        );
      }
      sekarang = DateTime(2026, 11, 29, 10);
      final hasilLemak = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(hasilLemak.berjalan, isNull);
      expect(hasilLemak.lencana, hasLength(2));
      expect(hasilLemak.lencana.first.jenis, JenisTantangan.lemak5);
    });

    test('catat_7: wajib 7 hari berturut-turut dalam jendela, bolong 1 hari berakhir setelah 7 hari', () async {
      await tantanganRepo.mulaiTantangan(JenisTantangan.catat7, waktuSekarang: sekarang);
      // Catat hari 16, 17, 19, 20, 21, 22 (bolong 18 Nov)
      for (final d in [16, 17, 19, 20, 21, 22]) {
        await asupanRepo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Snack', gulaG: 5),
          jumlahSajian: 1,
          waktuLokal: DateTime(2026, 11, d, 9),
        );
      }

      // Hari ke-7 (22 Nov) masih berjalan dengan sisa 0 hari
      sekarang = DateTime(2026, 11, 22, 20);
      final hari7 = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(hari7.berjalan, isNotNull);
      expect(hari7.berjalan!.sisaHari, 0);
      expect(hari7.berjalan!.terpenuhi, 6);

      // Hari ke-8 (23 Nov) jendela 7 hari lewat -> status berakhir, tanpa lencana
      sekarang = DateTime(2026, 11, 23, 8);
      final hari8 = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(hari8.berjalan, isNull);
      expect(hari8.berakhirTerbaru, isNotNull);
      expect(hari8.berakhirTerbaru!.status, StatusTantangan.berakhir);
      expect(hari8.lencana, isEmpty);

      // Mulai lagi catat_7 pada 23 Nov dan catat semua 7 hari (23..29 Nov) -> selesai
      await tantanganRepo.mulaiTantangan(JenisTantangan.catat7, waktuSekarang: sekarang);
      for (var d = 23; d <= 29; d++) {
        await asupanRepo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Air', gulaG: 0),
          jumlahSajian: 1,
          waktuLokal: DateTime(2026, 11, d, 10),
        );
      }
      sekarang = DateTime(2026, 11, 29, 12);
      final tercapai = await tantanganRepo.bacaStatus(waktuSekarang: sekarang);
      expect(tercapai.berjalan, isNull);
      expect(tercapai.berakhirTerbaru, isNull);
      expect(tercapai.lencana, hasLength(1));
      expect(tercapai.lencana.single.jenis, JenisTantangan.catat7);
    });

    test('hanya satu tantangan berjalan pada satu waktu', () async {
      await tantanganRepo.mulaiTantangan(JenisTantangan.gula5, waktuSekarang: sekarang);
      await expectLater(
        tantanganRepo.mulaiTantangan(JenisTantangan.natrium5, waktuSekarang: sekarang),
        throwsStateError,
      );
    });
  });

  group('UI Tantangan, Beranda, dan Profil', () {
    late DateTime sekarang;

    setUp(() async {
      sekarang = DateTime(2026, 11, 18, 10, 0);
      await siapkanDependensi(lokasiDb: inMemoryDatabasePath, jam: () => sekarang);
    });

    tearDown(() async {
      await resetDependensi();
    });

    testWidgets('Beranda menampilkan "Mulai tantangan" saat kosong, lalu kartu berjalan setelah mulai (320 px)',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      expect(find.text('Mulai tantangan'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.ensureVisible(find.text('Mulai tantangan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mulai tantangan'));
      await t.pumpAndSettle();

      expect(find.text('Pilih tantangan berikutnya'), findsOneWidget);
      expect(find.textContaining('kostum', findRichText: true), findsNothing);
      expect(find.textContaining('Hadiah'), findsNothing);

      // Mulai tantangan pertama (gula_5)
      await t.tap(find.text('Mulai').first);
      await t.pumpAndSettle();

      expect(find.text('BERJALAN · sisa 6 hari'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      expect(find.text('5 hari gula di bawah batas'), findsWidgets);
      expect(find.text('Berhasil'), findsOneWidget);
      expect(find.text('Belum berhasil'), findsOneWidget);
      expect(find.text('Hari mendatang'), findsOneWidget);

      // Saat ada yang berjalan, tombol Mulai yang tampil maupun setelah digulir nonaktif
      final tombolMulaiTerlihat = t.widgetList<InkWell>(find.widgetWithText(InkWell, 'Mulai')).toList();
      expect(tombolMulaiTerlihat, isNotEmpty);
      for (final tombol in tombolMulaiTerlihat) {
        expect(tombol.onTap, isNull);
      }
      await t.scrollUntilVisible(
        find.text('Catat jajanan 7 hari'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      for (final tombol in t.widgetList<InkWell>(find.widgetWithText(InkWell, 'Mulai'))) {
        expect(tombol.onTap, isNull);
      }

      // Kembali ke Beranda -> kartu tantangan berjalan tampil (Nuri pose 05, judul, 0/5)
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();

      expect(find.text('Tantangan: 5 hari gula di bawah batas'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TantanganPage menampilkan pesan berakhir tanpa menyalahkan dan lencana selesai dengan tanggal',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final repo = getIt<TantanganRepository>();
      // Tantangan berakhir tanpa tercapai (mulai 10 Nov, sekarang 18 Nov)
      await repo.mulaiTantangan(JenisTantangan.natrium5, waktuSekarang: DateTime(2026, 11, 10, 9));

      await t.pumpWidget(JeliLabelApp(awal: '/tantangan'));
      await t.pumpAndSettle();

      expect(find.text('Tantangan selesai. Coba lagi kapan saja.'), findsOneWidget);
      expect(find.textContaining('gagal'), findsNothing);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Beranda menampilkan lembar "Tantangan tercapai!" sekali saja dan Profil menampilkan n lencana',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final asupanRepo = getIt<AsupanRepository>();
      final tantanganRepo = getIt<TantanganRepository>();

      await tantanganRepo.mulaiTantangan(JenisTantangan.gula5, waktuSekarang: DateTime(2026, 11, 14, 8));
      for (var d = 14; d <= 18; d++) {
        await asupanRepo.simpanKonsumsi(
          draf: const DrafProduk(nama: 'Teh', gulaG: 15),
          jumlahSajian: 1,
          waktuLokal: DateTime(2026, 11, d, 9),
        );
      }

      await t.pumpWidget(JeliLabelApp(awal: '/beranda'));
      await t.pumpAndSettle();

      // Lembar ucapan tampil sekali dengan Nuri pose 05
      expect(find.text('Tantangan tercapai!'), findsOneWidget);
      expect(find.bySemanticsLabel('Nuri senang'), findsOneWidget);

      await t.tap(find.text('Tutup'));
      await t.pumpAndSettle();
      expect(find.text('Tantangan tercapai!'), findsNothing);

      // Pindah ke Profil -> nilai "1 lencana", lalu ke /tantangan -> ada lencana dengan tanggal
      await t.tap(find.text('Profil'));
      await t.pumpAndSettle();
      expect(find.text('Tantangan dan lencana'), findsOneWidget);
      expect(find.text('1 lencana'), findsOneWidget);

      await t.ensureVisible(find.text('Tantangan dan lencana'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tantangan dan lencana'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Lencana'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(find.text('Lencana'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Selesai 18 Nov'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('5 hari gula di bawah batas'), findsWidgets);
      expect(find.text('Selesai 18 Nov'), findsOneWidget);

      // Kembali ke Beranda dan buka ulang -> lembar tidak muncul lagi (sekali saja)
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();
      await t.tap(find.text('Beranda'));
      await t.pumpAndSettle();
      expect(find.text('Tantangan tercapai!'), findsNothing);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TantanganCubit mengunci mulai saat sedang menyimpan', (t) async {
      final cubit = getIt<TantanganCubit>();
      final f1 = cubit.mulai(JenisTantangan.gula5);
      final f2 = cubit.mulai(JenisTantangan.natrium5);
      final hasil = await Future.wait([f1, f2]);
      expect(hasil, [true, false]);
      await cubit.close();
    });
  });
}
