import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../pindai/kontrak_ocr.dart';
import '../pindai/layanan_iklan.dart';
import '../pindai/pemindai_label.dart';
import 'data/asupan_repository.dart';

export 'data/asupan_repository.dart' show BarisRiwayat, DrafProduk, RingkasanHari;

bool hariSama(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _awalHari(DateTime d) => DateTime(d.year, d.month, d.day);

class AsupanState extends Equatable {
  const AsupanState({
    this.daftar = const [],
    this.ringkasan = const RingkasanHari(),
    required this.hariAktif,
    this.ringkasan7Hari = const {},
    this.peringatanDitutup = const {},
    this.sisaKuota = kuotaGratisMingguan,
    this.bonusIklanDipakai = 0,
    this.memuat = false,
    this.memuatLagi = false,
    this.halamanHabis = false,
    this.galat,
  });

  static const kuotaGratisMingguan = 5;
  static const kuotaIklanMingguanMaks = 10;

  /// Halaman riwayat yang sudah dimuat, terbaru di depan.
  final List<BarisRiwayat> daftar;
  final RingkasanHari ringkasan;
  final DateTime hariAktif;
  final Map<String, ({double gula, double natrium})> ringkasan7Hari;

  /// Kunci `'<zat>-YYYY-MM-DD'` (F-08: paling banyak sekali per zat per hari).
  final Set<String> peringatanDitutup;

  final int sisaKuota;
  final int bonusIklanDipakai;
  final bool memuat;
  final bool memuatLagi;
  final bool halamanHabis;
  final String? galat;

  int get sisaSlotIklan => (kuotaIklanMingguanMaks - bonusIklanDipakai).clamp(0, kuotaIklanMingguanMaks);

  List<BarisRiwayat> padaTanggal(DateTime hari) {
    final tgl = tanggalLokal(hari);
    return daftar.where((k) => k.tanggal == tgl).toList();
  }

  double totalGula(DateTime hari) {
    if (hariSama(hari, hariAktif)) return ringkasan.totalGula;
    return ringkasan7Hari[tanggalLokal(hari)]?.gula ?? 0;
  }

  double totalNatrium(DateTime hari) {
    if (hariSama(hari, hariAktif)) return ringkasan.totalNatrium;
    return ringkasan7Hari[tanggalLokal(hari)]?.natrium ?? 0;
  }

  AsupanState copyWith({
    List<BarisRiwayat>? daftar,
    RingkasanHari? ringkasan,
    DateTime? hariAktif,
    Map<String, ({double gula, double natrium})>? ringkasan7Hari,
    Set<String>? peringatanDitutup,
    int? sisaKuota,
    int? bonusIklanDipakai,
    bool? memuat,
    bool? memuatLagi,
    bool? halamanHabis,
    String? galat,
    bool hapusGalat = false,
  }) =>
      AsupanState(
        daftar: daftar ?? this.daftar,
        ringkasan: ringkasan ?? this.ringkasan,
        hariAktif: hariAktif ?? this.hariAktif,
        ringkasan7Hari: ringkasan7Hari ?? this.ringkasan7Hari,
        peringatanDitutup: peringatanDitutup ?? this.peringatanDitutup,
        sisaKuota: sisaKuota ?? this.sisaKuota,
        bonusIklanDipakai: bonusIklanDipakai ?? this.bonusIklanDipakai,
        memuat: memuat ?? this.memuat,
        memuatLagi: memuatLagi ?? this.memuatLagi,
        halamanHabis: halamanHabis ?? this.halamanHabis,
        galat: hapusGalat ? null : (galat ?? this.galat),
      );

  @override
  List<Object?> get props => [
        daftar,
        ringkasan,
        hariAktif,
        ringkasan7Hari,
        peringatanDitutup,
        sisaKuota,
        bonusIklanDipakai,
        memuat,
        memuatLagi,
        halamanHabis,
        galat,
      ];
}

/// Mengelola status asupan harian, riwayat berhalaman, kuota, dan pengaturan lewat AsupanRepository.
class AsupanCubit extends Cubit<AsupanState> {
  AsupanCubit(
    this._repo, {
    DateTime Function()? jam,
    int ukuranHalaman = 30,
    int? sisaKuotaAwal,
    LayananIklanKuota? layananIklan,
    PemindaiLabel? pemindaiLabel,
  })  : _jam = jam ?? DateTime.now,
        // ignore: prefer_initializing_formals, parameter bernama tidak boleh privat
        _ukuranHalaman = ukuranHalaman,
        _sisaKuotaAwal = sisaKuotaAwal,
        _iklan = layananIklan ?? const LayananIklanSimulasi(),
        _pemindai = pemindaiLabel ?? PemindaiLabelSimulasi(),
        super(
          AsupanState(
            hariAktif: _awalHari((jam ?? DateTime.now)()),
            sisaKuota: sisaKuotaAwal ?? AsupanState.kuotaGratisMingguan,
          ),
        );

  final AsupanRepository _repo;
  final DateTime Function() _jam;
  final int _ukuranHalaman;
  final int? _sisaKuotaAwal;
  final LayananIklanKuota _iklan;
  final PemindaiLabel _pemindai;
  int _percobaanPindai = 0;
  Future<void>? _sinkronKuota;

  DateTime get sekarang => _jam();

  static const _kuotaMaksMingguan = AsupanState.kuotaGratisMingguan + AsupanState.kuotaIklanMingguanMaks;

  /// Menjalankan alur pemindaian lewat abstraksi [PemindaiLabel].
  /// Jika server mengembalikan `sisaKuotaServer`, nilai server dijadikan sumber kebenaran.
  Future<HasilPindai> pindaiLabel() async {
    if (state.sisaKuota <= 0) {
      return const HasilPindai.gagal(galat: GalatPindai.resourceExhausted);
    }
    try {
      final hasil = await _pemindai.pindai(sisaKuotaLokal: state.sisaKuota);
      if (isClosed) return hasil;
      if (hasil.berhasil) {
        final sisaBaru = hasil.sisaKuotaServer ?? (state.sisaKuota - 1).clamp(0, _kuotaMaksMingguan);
        emit(state.copyWith(sisaKuota: sisaBaru, hapusGalat: true));
        _sinkronKuota = _repo.tambahKuotaTerpakai(sekarang, maks: _kuotaMaksMingguan).then((_) {}, onError: (_) {});
      } else if (hasil.galat == GalatPindai.resourceExhausted) {
        emit(state.copyWith(sisaKuota: hasil.sisaKuotaServer ?? 0));
      } else if (hasil.sisaKuotaServer != null) {
        emit(state.copyWith(sisaKuota: hasil.sisaKuotaServer!));
      }
      return hasil;
    } catch (_) {
      return const HasilPindai.gagal(galat: GalatPindai.internal);
    }
  }

  /// Simulasi pindai (belum Gemini). Percobaan ke-5, 10, dst. gagal agar layar galat bisa dicoba.
  /// Kuota hanya berkurang bila label terbaca (PRD 14.2).
  DrafProduk? pindaiSimulasi() {
    if (state.sisaKuota <= 0) return null;
    _percobaanPindai++;
    if (_percobaanPindai % 5 == 0) return null;
    emit(state.copyWith(sisaKuota: (state.sisaKuota - 1).clamp(0, _kuotaMaksMingguan)));
    _sinkronKuota = _repo.tambahKuotaTerpakai(sekarang, maks: _kuotaMaksMingguan).then((_) {}, onError: (_) {});
    return const DrafProduk(
      nama: 'Susu UHT Cokelat',
      gulaG: 12,
      natriumMg: 95,
      takaranJumlah: 200,
      takaranSatuan: 'ml',
      sajianPerKemasan: 1,
      cekLagiNatrium: true,
    );
  }

  Future<bool> klaimBonusIklan() async {
    if (state.bonusIklanDipakai >= AsupanState.kuotaIklanMingguanMaks) return false;
    try {
      final selesai = await _iklan.tampilkanVideoHadiah();
      if (!selesai || isClosed) return false;
      await _sinkronKuota;
      final bonusBaru = await _repo.tambahBonusIklan(
        sekarang,
        maks: AsupanState.kuotaIklanMingguanMaks,
      );
      if (bonusBaru == null || isClosed) return false;
      emit(
        state.copyWith(
          bonusIklanDipakai: bonusBaru,
          sisaKuota: (state.sisaKuota + 1).clamp(0, _kuotaMaksMingguan),
          hapusGalat: true,
        ),
      );
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal memproses bonus iklan.'));
      return false;
    }
  }

  Future<void> muat({int? batasDaftar}) async {
    emit(state.copyWith(memuat: true, hapusGalat: true));
    try {
      await _sinkronKuota;
      final hari = _awalHari(sekarang);
      final batas = batasDaftar ?? _ukuranHalaman;
      final ringkasan = await _repo.ringkasanHari(hari);
      final halaman = await _repo.halamanRiwayat(batas: batas);
      final rentang = await _repo.ringkasanRentang(hari.subtract(const Duration(days: 6)), hari);
      final bolehGula = await _repo.bolehPeringatan('gula', hari);
      final bolehNatrium = await _repo.bolehPeringatan('natrium', hari);
      final statusKuota = await _repo.bacaStatusKuota(hari);
      if (isClosed) return;

      final tgl = tanggalLokal(hari);
      final ditutup = <String>{
        if (!bolehGula) 'gula-$tgl',
        if (!bolehNatrium) 'natrium-$tgl',
      };
      final sisaKuota = _sisaKuotaAwal ??
          (AsupanState.kuotaGratisMingguan + statusKuota.bonusIklan - statusKuota.terpakai).clamp(0, _kuotaMaksMingguan);

      emit(
        state.copyWith(
          daftar: halaman,
          ringkasan: ringkasan,
          hariAktif: hari,
          ringkasan7Hari: rentang,
          peringatanDitutup: ditutup,
          sisaKuota: sisaKuota,
          bonusIklanDipakai: statusKuota.bonusIklan.clamp(0, AsupanState.kuotaIklanMingguanMaks),
          memuat: false,
          halamanHabis: halaman.length < batas,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuat: false, galat: 'Gagal memuat data dari perangkat.'));
    }
  }

  Future<void> muatLagi() async {
    if (state.memuat || state.memuatLagi || state.halamanHabis || state.daftar.isEmpty) return;
    emit(state.copyWith(memuatLagi: true, hapusGalat: true));
    try {
      final terakhir = state.daftar.last;
      final tambahan = await _repo.halamanRiwayat(
        batas: _ukuranHalaman,
        sebelum: (tanggal: terakhir.tanggal, id: terakhir.id),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          daftar: [...state.daftar, ...tambahan],
          memuatLagi: false,
          halamanHabis: tambahan.length < _ukuranHalaman,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(memuatLagi: false, galat: 'Gagal memuat riwayat berikutnya.'));
    }
  }

  Future<bool> simpan(DrafProduk draf, double jumlahSajian, {String sumber = 'pindai'}) async {
    if (jumlahSajian <= 0) {
      throw ArgumentError.value(jumlahSajian, 'jumlahSajian', 'Harus lebih dari 0');
    }
    try {
      await _repo.simpanKonsumsi(
        draf: draf,
        jumlahSajian: jumlahSajian,
        waktuLokal: sekarang,
        sumber: sumber,
      );
      if (isClosed) return true;
      await muat();
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal menyimpan catatan.'));
      return false;
    }
  }

  Future<BarisRiwayat?> hapus(BarisRiwayat baris) async {
    final daftarSebelum = state.daftar;
    emit(
      state.copyWith(
        daftar: [
          for (final x in daftarSebelum)
            if (x.id != baris.id) x,
        ],
        hapusGalat: true,
      ),
    );
    try {
      final terhapus = await _repo.hapusKonsumsi(baris.id);
      if (isClosed) return terhapus ?? baris;
      final hari = _awalHari(sekarang);
      final ringkasan = await _repo.ringkasanHari(hari);
      final rentang = await _repo.ringkasanRentang(hari.subtract(const Duration(days: 6)), hari);
      if (!isClosed) {
        emit(state.copyWith(ringkasan: ringkasan, hariAktif: hari, ringkasan7Hari: rentang));
      }
      return terhapus ?? baris;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(daftar: daftarSebelum, galat: 'Gagal menghapus catatan.'));
      return null;
    }
  }

  Future<void> kembalikan(BarisRiwayat baris) async {
    try {
      await _repo.pulihkanKonsumsi(baris);
      if (isClosed) return;
      final batas = math.max(_ukuranHalaman, state.daftar.length + 1);
      await muat(batasDaftar: batas);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal mengembalikan catatan.'));
    }
  }

  Future<void> tutupPeringatan(String zat) async {
    final tgl = tanggalLokal(sekarang);
    emit(state.copyWith(peringatanDitutup: {...state.peringatanDitutup, '$zat-$tgl'}));
    try {
      await _repo.tandaiPeringatan(zat, sekarang);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal menyimpan status peringatan.'));
    }
  }

  bool peringatanTerbuka(String zat) => !state.peringatanDitutup.contains('$zat-${tanggalLokal(sekarang)}');

  Future<void> segarkan() async {
    final hariSekarang = _awalHari(sekarang);
    if (!hariSama(hariSekarang, state.hariAktif)) {
      await muat();
      return;
    }
    try {
      final ringkasan = await _repo.ringkasanHari(hariSekarang);
      final rentang = await _repo.ringkasanRentang(hariSekarang.subtract(const Duration(days: 6)), hariSekarang);
      if (!isClosed) {
        emit(state.copyWith(ringkasan: ringkasan, ringkasan7Hari: rentang));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal menyegarkan ringkasan.'));
    }
  }

  Future<void> selesaikanPerkenalan() async {
    try {
      await _repo.tandaiPerkenalanSelesai();
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal menyimpan status perkenalan.'));
    }
  }

  Future<String> eksporDataJson() => _repo.eksporDataJson(sekarang: sekarang);

  Future<String> eksporDataCsv() => _repo.eksporDataCsv();

  Future<int> jumlahCatatan() => _repo.jumlahKonsumsi();

  Future<void> resetSemuaData() async {
    try {
      await _sinkronKuota;
      await _repo.hapusSemuaData();
      if (isClosed) return;
      emit(
        AsupanState(
          hariAktif: _awalHari(sekarang),
          sisaKuota: _sisaKuotaAwal ?? AsupanState.kuotaGratisMingguan,
          bonusIklanDipakai: 0,
          halamanHabis: true,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(galat: 'Gagal menghapus semua data.'));
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await _sinkronKuota;
    return super.close();
  }
}
