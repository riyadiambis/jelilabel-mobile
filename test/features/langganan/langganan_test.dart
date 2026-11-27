import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/langganan/domain/layanan_langganan.dart';
import 'package:jelilabel/features/langganan/langganan_page.dart';
import 'package:jelilabel/features/langganan/presentation/langganan_cubit.dart';
import 'package:jelilabel/features/pindai/pindai_gagal_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Mock layanan: hasil beli dan status bisa diatur dari tes.
class _LayananFake implements LayananLangganan {
  _LayananFake({this.produk = const []});

  List<PaketPlus> produk;
  HasilBeli hasilBeli = HasilBeli.berhasil;
  bool pulihAktif = true;
  int beliDipanggil = 0;
  Completer<HasilBeli>? tahan;
  final _ctrl = StreamController<bool>.broadcast();
  bool _aktif = false;

  void _atur(bool v) {
    if (_aktif == v) return;
    _aktif = v;
    _ctrl.add(v);
  }

  /// Simulasi langganan berakhir (restorePurchases tanpa Plus).
  void berakhir() => _atur(false);

  @override
  Future<void> inisialisasi() async {}

  @override
  bool get plusAktif => _aktif;

  @override
  Stream<bool> get statusPlus => _ctrl.stream;

  @override
  Future<List<PaketPlus>> muatProduk() async => produk;

  @override
  Future<HasilBeli> beli(BasePlan basePlan) async {
    beliDipanggil++;
    final hasil = tahan != null ? await tahan!.future : hasilBeli;
    if (hasil == HasilBeli.berhasil) _atur(true);
    return hasil;
  }

  @override
  Future<bool> pulihkan() async {
    _atur(pulihAktif);
    return _aktif;
  }

  @override
  Future<void> tutup() async => _ctrl.close();
}

const _paket = [
  PaketPlus(basePlan: BasePlan.bulanan, harga: 'Rp15.000'),
  PaketPlus(basePlan: BasePlan.enamBulan, harga: 'Rp59.900'),
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('Efek Plus pada kuota (ISSUE-23)', () {
    late BasisData basis;
    late AsupanRepository repo;
    late _LayananFake layanan;
    final sekarang = DateTime(2026, 11, 26, 10);

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      repo = AsupanRepository(basis.db);
      layanan = _LayananFake(produk: _paket);
    });

    tearDown(() async {
      await layanan.tutup();
      await basis.tutup();
    });

    test('beli berhasil mengaktifkan Plus: kuota 100, plafon 100, slot iklan 0', () async {
      final asupan = AsupanCubit(repo, jam: () => sekarang, langganan: layanan);
      await asupan.muat();
      expect(asupan.state.sisaKuota, 5);
      final langganan = LanggananCubit(layanan);
      await langganan.muat();

      await langganan.beli();
      await Future<void>.delayed(Duration.zero);

      expect(langganan.state.plus, isTrue);
      expect(asupan.state.plus, isTrue);
      expect(asupan.state.sisaKuota, 100);
      expect(asupan.state.plafonKuota, 100);
      expect(asupan.state.sisaSlotIklan, 0);
      expect(await asupan.klaimBonusIklan(), isFalse);
      await langganan.close();
      await asupan.close();
    });

    test('Plus: kuota terpakai tersimpan melewati plafon gratis 15', () async {
      await layanan.beli(BasePlan.bulanan);
      final asupan = AsupanCubit(repo, jam: () => sekarang, langganan: layanan);
      await asupan.muat();
      var berhasil = 0;
      for (var i = 0; i < 24; i++) {
        if (asupan.pindaiSimulasi() != null) berhasil++;
      }
      await asupan.close();
      expect(berhasil, greaterThan(15));
      expect(asupan.state.sisaKuota, 100 - berhasil);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaTerpakai), '$berhasil');
    });

    test('beli dibatalkan tidak mengubah apa pun', () async {
      layanan.hasilBeli = HasilBeli.batal;
      final asupan = AsupanCubit(repo, jam: () => sekarang, langganan: layanan);
      await asupan.muat();
      final langganan = LanggananCubit(layanan);
      await langganan.muat();
      final sebelum = asupan.state;

      await langganan.beli();

      expect(langganan.state.plus, isFalse);
      expect(langganan.state.pesan, isNull);
      expect(langganan.state.proses, isFalse);
      expect(asupan.state, sebelum);
      expect(asupan.state.sisaKuota, 5);
      await langganan.close();
      await asupan.close();
    });

    test('beli gagal menampilkan pesan dan status tetap gratis', () async {
      layanan.hasilBeli = HasilBeli.gagal;
      final langganan = LanggananCubit(layanan);
      await langganan.muat();
      await langganan.beli();
      expect(langganan.state.plus, isFalse);
      expect(langganan.state.pesan, isNotNull);
      await langganan.close();
    });

    test('tombol beli dikunci selama proses: ketuk dua kali hanya memanggil layanan sekali', () async {
      layanan.tahan = Completer<HasilBeli>();
      final langganan = LanggananCubit(layanan);
      await langganan.muat();
      final pertama = langganan.beli();
      await langganan.beli();
      expect(langganan.state.proses, isTrue);
      expect(layanan.beliDipanggil, 1);
      layanan.tahan!.complete(HasilBeli.batal);
      await pertama;
      expect(langganan.state.proses, isFalse);
      await langganan.close();
    });

    test('pulihkan mengaktifkan kembali Plus', () async {
      final asupan = AsupanCubit(repo, jam: () => sekarang, langganan: layanan);
      await asupan.muat();
      final langganan = LanggananCubit(layanan);
      await langganan.muat();

      await langganan.pulihkan();
      await Future<void>.delayed(Duration.zero);

      expect(langganan.state.plus, isTrue);
      expect(asupan.state.plus, isTrue);
      expect(asupan.state.sisaKuota, 100);
      await langganan.close();
      await asupan.close();
    });

    test('pulihkan tanpa langganan: tetap gratis dengan pesan', () async {
      layanan.pulihAktif = false;
      final langganan = LanggananCubit(layanan);
      await langganan.pulihkan();
      expect(langganan.state.plus, isFalse);
      expect(langganan.state.pesan, 'Tidak ada langganan Plus yang ditemukan.');
      await langganan.close();
    });

    test('Plus berakhir: kembali ke kuota gratis tanpa menghapus data', () async {
      await layanan.beli(BasePlan.bulanan);
      final asupan = AsupanCubit(repo, jam: () => sekarang, langganan: layanan);
      await asupan.muat();
      for (var i = 0; i < 3; i++) {
        asupan.pindaiSimulasi();
      }
      await asupan.muat();
      expect(asupan.state.sisaKuota, 97);
      await repo.tambahKuotaBonusIklan(sekarang);
      await repo.simpanKonsumsi(
        draf: const DrafProduk(
          nama: 'Teh',
          gulaG: 10,
          natriumMg: 5,
          takaranJumlah: 200,
          takaranSatuan: 'ml',
          sajianPerKemasan: 1,
        ),
        jumlahSajian: 1,
        waktuLokal: sekarang,
      );

      layanan.berakhir();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(asupan.state.plus, isFalse);
      expect(asupan.state.plafonKuota, 6);
      expect(asupan.state.sisaKuota, 3); // 5 dasar + 1 bonus - 3 terpakai
      expect(asupan.state.sisaSlotIklan, 9);
      expect(await repo.jumlahKonsumsi(), 1);
      expect(await repo.bacaPengaturan(AsupanRepository.kunciKuotaTerpakai), '3');
      await asupan.close();
    });

    test('hapus semua data tidak menghapus status Plus tersimpan', () async {
      await repo.tulisPengaturan(AsupanRepository.kunciPlusAktif, '1');
      await repo.tulisPengaturan(AsupanRepository.kunciPlusTokenTerakhir, 'tok');
      await repo.tulisPengaturan('kuota_terpakai', '4');
      await repo.hapusSemuaData();
      expect(await repo.bacaPengaturan(AsupanRepository.kunciPlusAktif), '1');
      expect(await repo.bacaPengaturan(AsupanRepository.kunciPlusTokenTerakhir), 'tok');
      expect(await repo.bacaPengaturan('kuota_terpakai'), isNull);
    });
  });

  group('Layar', () {
    late BasisData basis;
    late AsupanRepository repo;

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      repo = AsupanRepository(basis.db);
    });

    tearDown(() async => basis.tutup());

    Future<void> tampilkan(WidgetTester t, Widget w) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: w));
      await t.pumpAndSettle();
    }

    testWidgets('harga dari layanan tampil, Langganan dikunci saat proses, Max Family tanpa tombol beli', (t) async {
      final layanan = _LayananFake(produk: _paket)..tahan = Completer<HasilBeli>();
      await tampilkan(t, LanggananPage(cubit: LanggananCubit(layanan)));

      expect(find.text('Rp15.000'), findsOneWidget);
      expect(find.text('Rp59.900'), findsOneWidget);
      expect(find.text('Langganan'), findsOneWidget);
      expect(find.text('Pulihkan pembelian'), findsOneWidget);
      expect(find.text('Tagihan lewat Google Play. Batalkan kapan saja di Play Store.'), findsOneWidget);
      expect(find.text('Max Family'), findsOneWidget);
      expect(find.text('Segera hadir'), findsOneWidget);

      await t.tap(find.text('6 bulan'));
      await t.pump();
      await t.tap(find.text('Langganan'));
      await t.pump();
      await t.tap(find.text('Langganan'), warnIfMissed: false);
      await t.pump();
      expect(layanan.beliDipanggil, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      layanan.tahan!.complete(HasilBeli.batal);
      await t.pumpAndSettle();
      expect(layanan.beliDipanggil, 1);
    });

    testWidgets('produk gagal dimuat: "Langganan belum tersedia" dan hanya Kembali', (t) async {
      await tampilkan(t, LanggananPage(cubit: LanggananCubit(_LayananFake())));
      expect(find.text('Langganan belum tersedia'), findsOneWidget);
      expect(find.text('Langganan'), findsNothing);
      expect(find.text('Pulihkan pembelian'), findsNothing);
      expect(find.text('Kembali'), findsOneWidget);
    });

    testWidgets('kuota habis saat Plus: tombol video iklan tersembunyi', (t) async {
      final layanan = _LayananFake()..berakhir();
      await layanan.beli(BasePlan.bulanan);
      final asupan = AsupanCubit(repo, langganan: layanan);
      await asupan.muat();
      addTearDown(asupan.close);

      await tampilkan(t, BlocProvider.value(value: asupan, child: const PindaiGagalPage.kuotaHabis()));
      expect(find.text('Tonton video, +1 pindai'), findsNothing);
      expect(find.text('Isi manual'), findsOneWidget);
    });

    testWidgets('kuota gratis habis: tombol video iklan tampil', (t) async {
      final asupan = AsupanCubit(repo, langganan: _LayananFake(), sisaKuotaAwal: 0);
      await asupan.muat();
      addTearDown(asupan.close);
      await tampilkan(t, BlocProvider.value(value: asupan, child: const PindaiGagalPage.kuotaHabis()));
      expect(find.text('Tonton video, +1 pindai'), findsOneWidget);
    });
  });
}
