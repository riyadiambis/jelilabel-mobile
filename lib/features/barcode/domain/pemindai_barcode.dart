import 'package:equatable/equatable.dart';

enum StatusPindaiBarcode { berhasil, batal, tidakTersedia }

/// Hasil pemindaian barcode kemasan (EAN-13, EAN-8, UPC-A, UPC-E).
class HasilPindaiBarcode extends Equatable {
  const HasilPindaiBarcode.berhasil(String this.kode) : status = StatusPindaiBarcode.berhasil;
  const HasilPindaiBarcode.batal()
      : status = StatusPindaiBarcode.batal,
        kode = null;
  const HasilPindaiBarcode.tidakTersedia()
      : status = StatusPindaiBarcode.tidakTersedia,
        kode = null;

  final StatusPindaiBarcode status;
  final String? kode;

  @override
  List<Object?> get props => [status, kode];
}

/// Antarmuka pemindai barcode agar dapat di-mock saat pengujian.
abstract interface class PemindaiBarcode {
  Future<HasilPindaiBarcode> pindai();
}
