import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Antarmuka berbagi gambar kartu supaya bisa di-mock di pengujian widget/unit.
abstract interface class LayananBagikan {
  Future<void> bagikanGambar({
    required Uint8List pngBytes,
    required String namaBerkas,
    String? teks,
  });
}

class LayananBagikanSharePlus implements LayananBagikan {
  const LayananBagikanSharePlus();

  @override
  Future<void> bagikanGambar({
    required Uint8List pngBytes,
    required String namaBerkas,
    String? teks,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(pngBytes, mimeType: 'image/png', name: namaBerkas)],
        text: teks,
      ),
    );
  }
}
