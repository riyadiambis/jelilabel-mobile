import 'package:flutter_test/flutter_test.dart';
import 'package:jelilabel/core/database/basis_data.dart';
import 'package:jelilabel/features/asupan/asupan_cubit.dart';
import 'package:jelilabel/features/asupan/data/asupan_repository.dart';
import 'package:jelilabel/features/pindai/kontrak_ocr.dart';
import 'package:jelilabel/features/pindai/pemindai_label.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PemindaiTiruan implements PemindaiLabel {
  _PemindaiTiruan(this.hasil);
  final HasilPindai hasil;

  @override
  Future<HasilPindai> pindai({required int sisaKuotaLokal}) async => hasil;
}

void main() {
  group('kontrak_ocr AI-CONTRACT.md v1.1', () {
    test('parseResponsOcr mengonversi garam_g * 400 saat natrium_mg null dan membaca kuota.sisa', () {
      final respons = parseResponsOcr({
        'hasil': {
          'terbaca': true,
          'takaran_saji': {'jumlah': 30, 'satuan': 'g'},
          'sajian_per_kemasan': 2,
          'per_sajian': {
            'energi_kkal': 140,
            'gula_g': 12,
            'natrium_mg': null,
            'garam_g': 0.5,
          },
        },
        'kuota': {'dasar': 5, 'bonusIklan': 1, 'terpakai': 4, 'sisa': 2, 'plafon': 15},
      });

      expect(respons.terbaca, isTrue);
      expect(respons.draf, isNotNull);
      expect(respons.draf!.gulaG, 12);
      expect(respons.draf!.natriumMg, 200);
      expect(respons.draf!.takaranJumlah, 30);
      expect(respons.draf!.takaranSatuan, 'g');
      expect(respons.draf!.sajianPerKemasan, 2);
      expect(respons.draf!.cekLagiGula, isFalse);
      expect(respons.draf!.cekLagiNatrium, isFalse);
      expect(respons.kuota?.sisa, 2);
      expect(respons.kuota?.plafon, 15);
    });

    test('validasiHasilOcr mengembalikan null jika terbaca false atau gula dan natrium null', () {
      expect(
        validasiHasilOcr({
          'terbaca': false,
          'per_sajian': {'gula_g': 10, 'natrium_mg': 100},
        }),
        isNull,
      );

      expect(
        validasiHasilOcr({
          'terbaca': true,
          'per_sajian': {'gula_g': null, 'natrium_mg': null, 'garam_g': null},
        }),
        isNull,
      );
    });

    test('validasiHasilOcr menandai cekLagi jika angka negatif atau gula > 100 / natrium > 5000', () {
      final tinggi = validasiHasilOcr({
        'terbaca': true,
        'takaran_saji': {'jumlah': 250, 'satuan': 'liter'},
        'per_sajian': {'gula_g': 101, 'natrium_mg': 5001},
      });
      expect(tinggi, isNotNull);
      expect(tinggi!.cekLagiGula, isTrue);
      expect(tinggi.cekLagiNatrium, isTrue);
      expect(tinggi.takaranSatuan, isNull);

      final negatif = validasiHasilOcr({
        'terbaca': true,
        'per_sajian': {'gula_g': -1, 'natrium_mg': -5},
      });
      expect(negatif!.cekLagiGula, isTrue);
      expect(negatif.cekLagiNatrium, isTrue);
    });

    test('pemetaan kode galat Cloud Functions sesuai kontrak', () {
      expect(galatPindaiDariKode('unauthenticated'), GalatPindai.unauthenticated);
      expect(galatPindaiDariKode('resource-exhausted'), GalatPindai.resourceExhausted);
      expect(galatPindaiDariKode('invalid-argument'), GalatPindai.invalidArgument);
      expect(galatPindaiDariKode('deadline-exceeded'), GalatPindai.deadlineExceeded);
      expect(galatPindaiDariKode('internal'), GalatPindai.internal);
      expect(pesanGalatPindai(GalatPindai.deadlineExceeded), 'Coba lagi');
      expect(pesanGalatPindai(GalatPindai.internal), 'Coba lagi nanti');
    });
  });

  group('AsupanCubit.pindaiLabel dan PemindaiLabel', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late BasisData basis;
    late AsupanRepository repo;

    setUp(() async {
      basis = await BasisData.buka(lokasiDb: inMemoryDatabasePath);
      repo = AsupanRepository(basis.db);
    });

    tearDown(() async {
      await basis.tutup();
    });

    test('memakai sisaKuotaServer sebagai sumber kebenaran saat pindai berhasil', () async {
      final cubit = AsupanCubit(
        repo,
        jam: () => DateTime(2026, 11, 20, 10),
        pemindaiLabel: _PemindaiTiruan(
          const HasilPindai.berhasil(
            draf: DrafProduk(nama: 'Teh', gulaG: 10),
            sisaKuotaServer: 2,
          ),
        ),
      );
      await cubit.muat();
      final hasil = await cubit.pindaiLabel();
      expect(hasil.berhasil, isTrue);
      expect(cubit.state.sisaKuota, 2);
      await cubit.close();
    });

    test('tidak mengurangi kuota saat gagal tidakTerbaca atau deadlineExceeded, dan nol saat resourceExhausted',
        () async {
      final gagalBaca = AsupanCubit(
        repo,
        jam: () => DateTime(2026, 11, 20, 10),
        pemindaiLabel: _PemindaiTiruan(const HasilPindai.gagal(galat: GalatPindai.tidakTerbaca)),
      );
      await gagalBaca.muat();
      expect((await gagalBaca.pindaiLabel()).berhasil, isFalse);
      expect(gagalBaca.state.sisaKuota, 5);
      await gagalBaca.close();

      final habis = AsupanCubit(
        repo,
        jam: () => DateTime(2026, 11, 20, 10),
        pemindaiLabel: _PemindaiTiruan(const HasilPindai.gagal(galat: GalatPindai.resourceExhausted)),
      );
      await habis.muat();
      final resHabis = await habis.pindaiLabel();
      expect(resHabis.galat, GalatPindai.resourceExhausted);
      expect(habis.state.sisaKuota, 0);
      await habis.close();
    });
  });
}
