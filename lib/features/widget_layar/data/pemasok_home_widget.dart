import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';

import '../domain/data_widget_layar.dart';

/// Implementasi [PemasokWidgetLayar] menggunakan paket `home_widget` untuk Android.
class PemasokHomeWidget implements PemasokWidgetLayar {
  const PemasokHomeWidget();

  static const _namaProviderAndroid = 'JeliLabelWidgetProvider';
  static const _namaLengkapProviderAndroid = 'com.ofilabs.jelilabel.JeliLabelWidgetProvider';

  @override
  Future<void> perbarui(DataWidgetLayar data) async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.saveWidgetData<bool>('ada_catatan', data.adaCatatan);
      await HomeWidget.saveWidgetData<String>('teks_sisa', data.teksSisa);
      await HomeWidget.saveWidgetData<String>('label_status', data.labelStatus);
      await HomeWidget.saveWidgetData<String>('kode_status', data.kodeStatus);
      await HomeWidget.saveWidgetData<int>('persen_terpakai', data.persenTerpakai);
      await HomeWidget.saveWidgetData<String>('diperbarui', data.diperbarui);
      await HomeWidget.updateWidget(
        androidName: _namaProviderAndroid,
        qualifiedAndroidName: _namaLengkapProviderAndroid,
      );
    } catch (_) {
      // Abaikan galat platform agar alur simpan/hapus asupan tetap aman.
    }
  }

  @override
  Future<Uri?> tautanAwal() async {
    if (!Platform.isAndroid) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri?> get aliranKetuk {
    if (!Platform.isAndroid) return const Stream.empty();
    return HomeWidget.widgetClicked.handleError((_) {});
  }
}
