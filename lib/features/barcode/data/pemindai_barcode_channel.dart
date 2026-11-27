import 'package:flutter/services.dart';

import '../domain/pemindai_barcode.dart';

/// Implementasi [PemindaiBarcode] memakai Google Code Scanner lewat MethodChannel Android.
class PemindaiBarcodeChannel implements PemindaiBarcode {
  const PemindaiBarcodeChannel();

  static const channel = MethodChannel('jelilabel/barcode');

  @override
  Future<HasilPindaiBarcode> pindai() async {
    try {
      final nilai = await channel.invokeMethod<String?>('pindai');
      final bersih = nilai?.trim();
      if (bersih == null || bersih.isEmpty) {
        return const HasilPindaiBarcode.batal();
      }
      return HasilPindaiBarcode.berhasil(bersih);
    } on PlatformException catch (e) {
      if (e.code == 'batal') {
        return const HasilPindaiBarcode.batal();
      }
      return const HasilPindaiBarcode.tidakTersedia();
    } on MissingPluginException {
      return const HasilPindaiBarcode.tidakTersedia();
    }
  }
}
