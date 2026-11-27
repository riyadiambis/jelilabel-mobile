import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../../asupan/data/asupan_repository.dart' show tanggalLokal;
import '../domain/sesi_olahraga.dart';
import '../domain/sumber_aktivitas.dart';

/// Implementasi [SumberAktivitas] memakai paket `health` (baca saja dari Health Connect).
class SumberAktivitasHealth implements SumberAktivitas {
  SumberAktivitasHealth({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _sudahKonfigurasi = false;

  static const _jenisIzin = [
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
  ];

  static const _aksesBaca = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<void> _pastikanKonfigurasi() async {
    if (_sudahKonfigurasi) return;
    await _health.configure();
    _sudahKonfigurasi = true;
  }

  @override
  Future<bool> tersedia() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _health.getHealthConnectSdkStatus() == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<StatusHealthConnect> statusPerangkat() async {
    if (!Platform.isAndroid) return StatusHealthConnect.tidakDidukung;
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return switch (status) {
        HealthConnectSdkStatus.sdkAvailable => StatusHealthConnect.tersedia,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => StatusHealthConnect.perluPasang,
        _ => StatusHealthConnect.tidakDidukung,
      };
    } catch (_) {
      return StatusHealthConnect.tidakDidukung;
    }
  }

  @override
  Future<bool> sudahDiizinkan() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!await tersedia()) return false;
      final langkah = await _health.hasPermissions(
            const [HealthDataType.STEPS],
            permissions: const [HealthDataAccess.READ],
          ) ??
          false;
      final olahraga = await _health.hasPermissions(
            const [HealthDataType.WORKOUT],
            permissions: const [HealthDataAccess.READ],
          ) ??
          false;
      return langkah || olahraga;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> mintaIzin() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!await tersedia()) return false;
      await _pastikanKonfigurasi();
      final hasil = await _health.requestAuthorization(_jenisIzin, permissions: _aksesBaca);
      if (!hasil) return false;
      return await sudahDiizinkan();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> bukaPlayStore() async {
    if (!Platform.isAndroid) return;
    try {
      await _health.installHealthConnect();
    } catch (_) {
      // Abaikan galat agar aplikasi tetap stabil.
    }
  }

  @override
  Future<int?> langkahHari(DateTime tanggal) async {
    if (!Platform.isAndroid) return null;
    try {
      if (!await tersedia()) return null;
      final izinLangkah = await _health.hasPermissions(
            const [HealthDataType.STEPS],
            permissions: const [HealthDataAccess.READ],
          ) ??
          false;
      if (!izinLangkah) return null;
      await _pastikanKonfigurasi();
      final l = tanggal.isUtc ? tanggal.toLocal() : tanggal;
      final awal = DateTime(l.year, l.month, l.day);
      final akhir = awal.add(const Duration(days: 1));
      return await _health.getTotalStepsInInterval(awal, akhir);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, int>> langkahRentang(DateTime dari, DateTime sampai) async {
    if (!Platform.isAndroid) return {};
    try {
      if (!await tersedia()) return {};
      final izinLangkah = await _health.hasPermissions(
            const [HealthDataType.STEPS],
            permissions: const [HealthDataAccess.READ],
          ) ??
          false;
      if (!izinLangkah) return {};
      await _pastikanKonfigurasi();
      final lDari = dari.isUtc ? dari.toLocal() : dari;
      final lSampai = sampai.isUtc ? sampai.toLocal() : sampai;
      final awal = DateTime(lDari.year, lDari.month, lDari.day);
      final akhir = DateTime(lSampai.year, lSampai.month, lSampai.day).add(const Duration(days: 1));
      if (!akhir.isAfter(awal)) return {};

      final titik = await _health.getHealthIntervalDataFromTypes(
        startDate: awal,
        endDate: akhir,
        types: const [HealthDataType.STEPS],
        interval: const Duration(days: 1).inSeconds,
      );
      final hasil = <String, int>{};
      for (final p in titik) {
        final v = p.value;
        if (v is NumericHealthValue) {
          final k = tanggalLokal(p.dateFrom);
          hasil[k] = (hasil[k] ?? 0) + v.numericValue.round();
        }
      }
      return hasil;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<SesiOlahraga>> sesiOlahraga(DateTime dari, DateTime sampai) async {
    if (!Platform.isAndroid) return [];
    try {
      if (!await tersedia()) return [];
      final izinOlahraga = await _health.hasPermissions(
            const [HealthDataType.WORKOUT],
            permissions: const [HealthDataAccess.READ],
          ) ??
          false;
      if (!izinOlahraga) return [];
      await _pastikanKonfigurasi();
      final lDari = dari.isUtc ? dari.toLocal() : dari;
      final lSampai = sampai.isUtc ? sampai.toLocal() : sampai;
      final awal = DateTime(lDari.year, lDari.month, lDari.day);
      final akhir = DateTime(lSampai.year, lSampai.month, lSampai.day).add(const Duration(days: 1));
      if (!akhir.isAfter(awal)) return [];

      final titik = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: awal,
        endTime: akhir,
      );
      final daftar = <SesiOlahraga>[];
      for (final p in titik) {
        final v = p.value;
        if (v is! WorkoutHealthValue) continue;
        final mulai = p.dateFrom.isUtc ? p.dateFrom.toLocal() : p.dateFrom;
        final selesai = p.dateTo.isUtc ? p.dateTo.toLocal() : p.dateTo;
        final durasi = selesai.isAfter(mulai) ? selesai.difference(mulai) : Duration.zero;
        final jarak = v.totalDistance != null && v.totalDistance! > 0
            ? _konversiKeMeter(v.totalDistance!, v.totalDistanceUnit)
            : null;
        daftar.add(
          SesiOlahraga(
            jenis: _petaJenis(v.workoutActivityType),
            mulai: mulai,
            durasi: durasi,
            jarakMeter: jarak,
          ),
        );
      }
      daftar.sort((a, b) => b.mulai.compareTo(a.mulai));
      return daftar;
    } catch (_) {
      return [];
    }
  }

  static double _konversiKeMeter(int nilai, HealthDataUnit? unit) => switch (unit) {
        HealthDataUnit.CENTIMETER => nilai / 100.0,
        HealthDataUnit.MILE => nilai * 1609.344,
        _ => nilai.toDouble(),
      };

  static JenisOlahraga _petaJenis(HealthWorkoutActivityType tipe) => switch (tipe) {
        HealthWorkoutActivityType.WALKING ||
        HealthWorkoutActivityType.WALKING_TREADMILL ||
        HealthWorkoutActivityType.HIKING =>
          JenisOlahraga.jalan,
        HealthWorkoutActivityType.RUNNING_TREADMILL => JenisOlahraga.jogging,
        HealthWorkoutActivityType.RUNNING || HealthWorkoutActivityType.TRACK_AND_FIELD => JenisOlahraga.lari,
        _ => JenisOlahraga.lainnya,
      };
}
