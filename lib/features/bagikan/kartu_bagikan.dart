import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/di/injeksi.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import 'data_kartu_bagikan.dart';
import 'layanan_bagikan.dart';

/// Membuka lembar pratinjau kartu bagikan (F2) dan mengekspor PNG via [LayananBagikan].
Future<void> tampilkanLembarBagikan(BuildContext context, DataKartuBagikan data) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => LembarBagikan(data: data),
    );

class LembarBagikan extends StatefulWidget {
  const LembarBagikan({super.key, required this.data});
  final DataKartuBagikan data;

  @override
  State<LembarBagikan> createState() => _LembarBagikanState();
}

class _LembarBagikanState extends State<LembarBagikan> {
  final _boundaryKey = GlobalKey();
  bool _sedangBagikan = false;

  Future<void> _bagikan() async {
    if (_sedangBagikan) return;
    setState(() => _sedangBagikan = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Kartu belum siap dirender');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Gagal membuat gambar PNG');
      }
      final pngBytes = byteData.buffer.asUint8List();
      await getIt<LayananBagikan>().bagikanGambar(
        pngBytes: pngBytes,
        namaBerkas: 'jelilabel-kartu.png',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal membagikan kartu. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _sedangBagikan = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s12, Jarak.layar, Jarak.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: Jarak.s4,
                decoration: BoxDecoration(color: Warna.garis, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: Jarak.s8),
            Row(
              children: [
                Expanded(child: Text('Bagikan ke teman', style: judulKecil())),
                IconButton(
                  onPressed: _sedangBagikan ? null : () => Navigator.pop(context),
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
                ),
              ],
            ),
            const SizedBox(height: Jarak.s12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: KartuBagikan(data: widget.data),
                ),
              ),
            ),
            const SizedBox(height: Jarak.s20),
            TombolTebal(
              label: _sedangBagikan ? 'Menyiapkan gambar...' : 'Bagikan',
              ikon: Icons.share_outlined,
              memuat: _sedangBagikan,
              onPressed: _sedangBagikan ? null : _bagikan,
            ),
            const SizedBox(height: Jarak.s12),
            Text(
              'Gambar dibuat di HP. Foto label tidak ikut dibagikan.',
              style: teksKecil(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

/// Kartu "setara sendok" bergaya F2 untuk dirender ke PNG lewat [RepaintBoundary].
class KartuBagikan extends StatelessWidget {
  const KartuBagikan({super.key, required this.data});
  final DataKartuBagikan data;

  @override
  Widget build(BuildContext context) {
    final info = data.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Jarak.s20),
      decoration: BoxDecoration(
        color: Warna.oranyeLembut,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Warna.oranyeTepi, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            data.labelPorsi,
            style: teksLabel(bobot: FontWeight.w800, warna: Warna.oranyeTeks),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Jarak.s8),
          Text(
            data.namaProduk,
            style: judul(tinggi: 1.1),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Jarak.s8),
          Text('setara', style: teksLabel(bobot: FontWeight.w700)),
          const SizedBox(height: Jarak.s8),
          Text(info.teksAngka, style: judulBesar(tinggi: 1.0), textAlign: TextAlign.center),
          const SizedBox(height: Jarak.s4),
          Text(info.satuanSendok, style: judulKecil(tinggi: 1.15), textAlign: TextAlign.center),
          if (info.teksAngka != '-') ...[
            const SizedBox(height: Jarak.s12),
            _DeretanSendok(jumlahSendok: info.jumlahSendok, keterangan: '${info.teksAngka} ${info.satuanSendok}'),
          ],
          const SizedBox(height: Jarak.s12),
          Text(
            info.teksPersen,
            style: teksKecil(bobot: FontWeight.w700, warna: Warna.tintaLembut, tinggi: 1.35),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Jarak.s16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Maskot('01-mengintip', ukuran: 32),
              const SizedBox(width: Jarak.s8),
              Flexible(
                child: Text(
                  'Dicek dengan JeliLabel',
                  style: teksLabel(bobot: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeretanSendok extends StatelessWidget {
  const _DeretanSendok({required this.jumlahSendok, required this.keterangan});
  final double jumlahSendok;
  final String keterangan;

  static const _sudutDerajat = [-6.0, 4.0, -3.0, 5.0, 6.0];

  @override
  Widget build(BuildContext context) {
    final penuh = jumlahSendok.floor();
    final adaSetengah = (jumlahSendok - penuh) >= 0.5;
    final ikon = <_JenisSendok>[];
    if (penuh == 0 && !adaSetengah) {
      ikon.add(_JenisSendok.kosong);
    } else {
      for (var i = 0; i < math.min(penuh, 5); i++) {
        ikon.add(_JenisSendok.penuh);
      }
      if (adaSetengah && ikon.length < 5) {
        ikon.add(_JenisSendok.setengah);
      }
    }
    final lebih = penuh > 5 || (penuh == 5 && adaSetengah);

    return Semantics(
      image: true,
      label: keterangan,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, jenis) in ikon.indexed) ...[
            if (i > 0) const SizedBox(width: Jarak.s4),
            Transform.rotate(
              angle: _sudutDerajat[i % _sudutDerajat.length] * math.pi / 180,
              child: CustomPaint(
                size: const Size(34, 84),
                painter: _PelukisSendok(jenis),
              ),
            ),
          ],
          if (lebih) ...[
            const SizedBox(width: Jarak.s4),
            Text('+', style: judulKecil(warna: Warna.oranyeTeks)),
          ],
        ],
      ),
    );
  }
}

enum _JenisSendok { penuh, setengah, kosong }

class _PelukisSendok extends CustomPainter {
  const _PelukisSendok(this.jenis);
  final _JenisSendok jenis;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 40;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    final badan = Path()
      ..moveTo(20, 4)
      ..cubicTo(30, 4, 34, 14, 34, 22)
      ..cubicTo(34, 32, 27, 40, 22, 42)
      ..lineTo(21.5, 60)
      ..cubicTo(21.5, 66, 25, 78, 25, 88)
      ..cubicTo(25, 94, 22.5, 97, 20, 97)
      ..cubicTo(17.5, 97, 15, 94, 15, 88)
      ..cubicTo(15, 78, 18.5, 66, 18.5, 60)
      ..lineTo(18, 42)
      ..cubicTo(13, 40, 6, 32, 6, 22)
      ..cubicTo(6, 14, 10, 4, 20, 4)
      ..close();

    canvas.drawPath(badan, Paint()..color = Warna.kartu);
    canvas.drawPath(
      badan,
      Paint()
        ..color = Warna.tinta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(20, 23), width: 20, height: 28),
      Paint()..color = Warna.jalurBilah,
    );

    final kilau = Path()
      ..moveTo(19.5, 66)
      ..cubicTo(19.5, 74, 21, 82, 21, 88);
    canvas.drawPath(
      kilau,
      Paint()
        ..color = Warna.garis
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    if (jenis == _JenisSendok.penuh) {
      final isi = Path()
        ..moveTo(8.5, 25)
        ..cubicTo(9.5, 14, 15, 9.5, 20, 9.5)
        ..cubicTo(25, 9.5, 30.5, 14, 31.5, 25)
        ..cubicTo(26, 29.5, 14, 29.5, 8.5, 25)
        ..close();
      _gambarIsi(canvas, isi, const [
        Offset(15.5, 16.5),
        Offset(22.5, 14.5),
        Offset(19, 21.5),
        Offset(26, 21),
        Offset(13, 22.5),
      ]);
    } else if (jenis == _JenisSendok.setengah) {
      final isi = Path()
        ..moveTo(10, 28)
        ..cubicTo(12.5, 21, 16.5, 18.5, 20, 18.5)
        ..cubicTo(23.5, 18.5, 27.5, 21, 30, 28)
        ..cubicTo(25, 31.5, 15, 31.5, 10, 28)
        ..close();
      _gambarIsi(canvas, isi, const [
        Offset(17, 24.5),
        Offset(23, 23.5),
      ]);
    }

    canvas.restore();
  }

  void _gambarIsi(Canvas canvas, Path isi, List<Offset> butir) {
    canvas.drawPath(isi, Paint()..color = Warna.kartu);
    canvas.drawPath(
      isi,
      Paint()
        ..color = Warna.tinta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    final isiButir = Paint()..color = Warna.kartu;
    final tepiButir = Paint()
      ..color = Warna.garisBatas
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (final p in butir) {
      final r = Rect.fromCenter(center: p, width: 3, height: 3);
      canvas.drawRect(r, isiButir);
      canvas.drawRect(r, tepiButir);
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisSendok oldDelegate) => oldDelegate.jenis != jenis;
}
