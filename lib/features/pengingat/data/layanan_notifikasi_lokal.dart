import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ignore: depend_on_referenced_packages
import 'package:timezone/data/latest_all.dart' as tz_data;
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;

import '../domain/layanan_notifikasi.dart';

/// Implementasi [LayananNotifikasi] memakai `flutter_local_notifications` mode inexact (tanpa exact alarm).
class LayananNotifikasiLokal implements LayananNotifikasi {
  LayananNotifikasiLokal({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelZona = MethodChannel('jelilabel/zona_waktu');
  static const _channelId = 'pengingat_harian';
  static const _channelName = 'Pengingat harian';
  static const _channelDesc = 'Pengingat harian untuk mencatat jajanan';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _sudahInisialisasi = false;
  bool _sudahZona = false;

  Future<void> _pastikanZona() async {
    if (_sudahZona) return;
    tz_data.initializeTimeZones();
    String? namaZona;
    if (Platform.isAndroid) {
      try {
        namaZona = await _channelZona.invokeMethod<String>('zonaLokal');
      } catch (_) {
        namaZona = null;
      }
    }
    if (namaZona != null && namaZona.isNotEmpty) {
      try {
        tz.setLocalLocation(tz.getLocation(namaZona));
        _sudahZona = true;
        return;
      } catch (_) {
        // Fallback ke pencocokan offset bila nama zona tidak dikenal.
      }
    }
    final offset = DateTime.now().timeZoneOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offset) {
        tz.setLocalLocation(loc);
        _sudahZona = true;
        return;
      }
    }
    tz.setLocalLocation(tz.UTC);
    _sudahZona = true;
  }

  @override
  Future<void> inisialisasi({void Function(String? payload)? onKetuk}) async {
    if (!Platform.isAndroid) return;
    if (_sudahInisialisasi) return;
    await _pastikanZona();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (respons) {
        onKetuk?.call(respons.payload);
      },
    );
    _sudahInisialisasi = true;
  }

  @override
  Future<String?> payloadPeluncuranAwal() async {
    if (!Platform.isAndroid) return null;
    try {
      final detail = await _plugin.getNotificationAppLaunchDetails();
      if (detail?.didNotificationLaunchApp ?? false) {
        return detail?.notificationResponse?.payload;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> mintaIzinNotifikasi() async {
    if (!Platform.isAndroid) return false;
    await inisialisasi();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final diizinkan = await android.requestNotificationsPermission();
    return diizinkan ?? false;
  }

  @override
  Future<void> jadwalkanHarianInexact({
    required int id,
    required String judul,
    required String isi,
    required DateTime waktuLokal,
    required bool ulangiHarian,
    String? payload,
  }) async {
    if (!Platform.isAndroid) return;
    await inisialisasi();
    await _pastikanZona();
    final l = waktuLokal.isUtc ? waktuLokal.toLocal() : waktuLokal;
    final tzWaktu = tz.TZDateTime(tz.local, l.year, l.month, l.day, l.hour, l.minute);

    const detail = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: judul,
      body: isi,
      scheduledDate: tzWaktu,
      notificationDetails: detail,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: ulangiHarian ? DateTimeComponents.time : null,
      payload: payload,
    );
  }

  @override
  Future<void> batalkan(int id) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: id);
  }
}
