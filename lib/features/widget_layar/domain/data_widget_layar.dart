import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../core/ambang.dart';
import '../../../core/format.dart';
import '../../asupan/data/asupan_repository.dart';
import '../../profil/domain/profil_batas.dart';

/// Ringkasan tampilan widget layar utama Android 4x2 (F-17).
class DataWidgetLayar extends Equatable {
  const DataWidgetLayar({
    required this.adaCatatan,
    required this.teksSisa,
    required this.labelStatus,
    required this.kodeStatus,
    required this.persenTerpakai,
    required this.diperbarui,
    this.status,
  });

  final bool adaCatatan;
  final String teksSisa;
  final String labelStatus;
  final String kodeStatus;
  final int persenTerpakai;
  final String diperbarui;
  final StatusHarian? status;

  @override
  List<Object?> get props => [
        adaCatatan,
        teksSisa,
        labelStatus,
        kodeStatus,
        persenTerpakai,
        diperbarui,
        status,
      ];
}

/// Menghitung data widget dari ringkasan hari ini, fokus & batas profil aktif, dan waktu sekarang.
DataWidgetLayar hitungDataWidgetLayar({
  required RingkasanHari ringkasan,
  required ProfilPengguna profil,
  required DateTime waktu,
}) {
  final diperbarui = 'diperbarui ${jam(waktu)}';
  if (ringkasan.jumlahCatatan <= 0) {
    return DataWidgetLayar(
      adaCatatan: false,
      teksSisa: '',
      labelStatus: '',
      kodeStatus: '',
      persenTerpakai: 0,
      diperbarui: diperbarui,
    );
  }

  final batas = profil.batasHarian;
  final fokus = profil.fokus ?? FokusZat.gula;
  final ({String nama, String satuan, double total, double batasZat}) info = switch (fokus) {
    FokusZat.gula => (nama: 'Gula', satuan: 'g', total: ringkasan.totalGula, batasZat: batas.gulaG),
    FokusZat.natrium => (nama: 'Natrium', satuan: 'mg', total: ringkasan.totalNatrium, batasZat: batas.natriumMg),
    FokusZat.lemak => (nama: 'Lemak', satuan: 'g', total: ringkasan.totalLemak, batasZat: batas.lemakG),
  };

  final sisa = math.max(0.0, info.batasZat - info.total);
  final st = statusHarian(info.total, info.batasZat);
  final (labelStatus, kodeStatus) = switch (st) {
    StatusHarian.aman => ('Aman', 'aman'),
    StatusHarian.hampirBatas => ('Hampir batas', 'hampir_batas'),
    StatusHarian.lewatBatas => ('Lewat batas', 'lewat_batas'),
  };
  final persen = info.batasZat <= 0 ? 0 : ((info.total / info.batasZat) * 100).round().clamp(0, 100);

  return DataWidgetLayar(
    adaCatatan: true,
    teksSisa: '${info.nama} sisa ${angka(sisa)} ${info.satuan}',
    labelStatus: labelStatus,
    kodeStatus: kodeStatus,
    persenTerpakai: persen,
    diperbarui: diperbarui,
    status: st,
  );
}

/// Kontrak pengiriman data dan penerima deep link widget layar utama.
abstract class PemasokWidgetLayar {
  Future<void> perbarui(DataWidgetLayar data);

  Future<Uri?> tautanAwal();

  Stream<Uri?> get aliranKetuk;
}
