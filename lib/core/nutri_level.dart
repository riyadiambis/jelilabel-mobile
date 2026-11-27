/// Perkiraan Nutri-Level minuman siap saji per 100 mL (docs/NUTRI-LEVEL.md, Kepmenkes 301/2026).
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

enum LevelNutri {
  a('A'),
  b('B'),
  c('C'),
  d('D');

  const LevelNutri(this.huruf);
  final String huruf;
}

class HasilNutriLevel extends Equatable {
  const HasilNutriLevel({
    required this.level,
    this.tidakLengkap = false,
  });

  final LevelNutri level;
  final bool tidakLengkap;

  String get huruf => level.huruf;

  @override
  List<Object?> get props => [level, tidakLengkap];
}

const _batasGulaA = 1.0;
const _batasGulaB = 5.0;
const _batasGulaC = 10.0;

const _batasNatriumA = 5.0;
const _batasNatriumB = 120.0;
const _batasNatriumC = 500.0;

const _batasLemakJenuhA = 0.7;
const _batasLemakJenuhB = 1.2;
const _batasLemakJenuhC = 2.8;

LevelNutri _levelDariAmbang(double nilaiPer100Ml, double batasA, double batasB, double batasC) {
  if (nilaiPer100Ml <= batasA) return LevelNutri.a;
  if (nilaiPer100Ml <= batasB) return LevelNutri.b;
  if (nilaiPer100Ml <= batasC) return LevelNutri.c;
  return LevelNutri.d;
}

bool _tidakValid(double? v) => v != null && (!v.isFinite || v < 0);

/// Menghitung perkiraan Nutri-Level minuman dari nilai gizi per sajian.
/// Mengembalikan `null` bila satuan bukan `ml`, takaran tidak sah/nol, atau ketiga zat utama `null`.
HasilNutriLevel? perkiraanNutriLevel({
  double? takaranJumlah,
  String? takaranSatuan,
  double? gulaG,
  double? laktosaG,
  double? natriumMg,
  double? lemakJenuhG,
}) {
  if (takaranSatuan == null || takaranSatuan.toLowerCase() != 'ml') return null;
  if (takaranJumlah == null || !takaranJumlah.isFinite || takaranJumlah <= 0) return null;
  if (_tidakValid(gulaG) || _tidakValid(laktosaG) || _tidakValid(natriumMg) || _tidakValid(lemakJenuhG)) {
    return null;
  }
  if (gulaG == null && natriumMg == null && lemakJenuhG == null) return null;

  final tidakLengkap = gulaG == null || natriumMg == null || lemakJenuhG == null;
  final daftarLevel = <LevelNutri>[];

  if (gulaG != null) {
    final gulaBersih = math.max(0.0, gulaG - (laktosaG ?? 0.0));
    final gula100 = (gulaBersih * 100.0) / takaranJumlah;
    daftarLevel.add(_levelDariAmbang(gula100, _batasGulaA, _batasGulaB, _batasGulaC));
  }
  if (natriumMg != null) {
    final natrium100 = (natriumMg * 100.0) / takaranJumlah;
    daftarLevel.add(_levelDariAmbang(natrium100, _batasNatriumA, _batasNatriumB, _batasNatriumC));
  }
  if (lemakJenuhG != null) {
    final lemakJenuh100 = (lemakJenuhG * 100.0) / takaranJumlah;
    daftarLevel.add(_levelDariAmbang(lemakJenuh100, _batasLemakJenuhA, _batasLemakJenuhB, _batasLemakJenuhC));
  }

  final terburuk = daftarLevel.reduce((a, b) => b.index > a.index ? b : a);
  return HasilNutriLevel(level: terburuk, tidakLengkap: tidakLengkap);
}
