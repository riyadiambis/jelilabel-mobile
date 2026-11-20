import 'package:flutter/material.dart';

import '../ambang.dart';
import '../theme/tema.dart';
import '../theme/warna.dart';

/// Tombol tebal dengan tepi bawah lebih gelap (UI-GUIDE: terasa bisa ditekan).
class TombolTebal extends StatelessWidget {
  const TombolTebal({
    super.key,
    required this.label,
    required this.onPressed,
    this.ikon,
    this.warna = Warna.hijauTua,
    this.tepi = Warna.hijauTepi,
    this.warnaTeks = Colors.white,
    this.tinggi = 56,
  });

  /// Tombol Pindai: oranye, teks tinta (teks putih di atas oranye dilarang).
  const TombolTebal.pindai({super.key, required this.label, required this.onPressed, this.ikon})
      : warna = Warna.oranye,
        tepi = Warna.oranyeTepi,
        warnaTeks = Warna.tinta,
        tinggi = 60;

  /// Tombol sekunder: putih bergaris.
  const TombolTebal.sekunder({super.key, required this.label, required this.onPressed, this.ikon})
      : warna = Warna.kartu,
        tepi = Warna.garis,
        warnaTeks = Warna.tinta,
        tinggi = 56;

  final String label;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final Color warna;
  final Color tepi;
  final Color warnaTeks;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    return Semantics(
      button: true,
      enabled: aktif,
      child: Material(
        color: aktif ? warna : Warna.garis,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: warna == Warna.kartu ? const BorderSide(color: Warna.garis, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: tinggi,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: aktif ? tepi : Warna.garis, width: 4))),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            // Row min: tombol bisa dipakai di dalam Row lain (lebar tak terbatas) tanpa galat flex.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ikon != null) ...[Icon(ikon, color: warnaTeks, size: 22), const SizedBox(width: 10)],
                Text(label, style: fredoka(17, warna: warnaTeks), maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu putih dengan bayangan bawah tipis.
class KartuPutih extends StatelessWidget {
  const KartuPutih({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Warna.garis),
          boxShadow: const [BoxShadow(color: Warna.garisBayangan, offset: Offset(0, 3))],
        ),
        child: child,
      );
}

class Maskot extends StatelessWidget {
  const Maskot(this.pose, {super.key, this.ukuran = 200, this.label});

  /// Nama berkas tanpa awalan, mis. '01-mengintip'.
  final String pose;
  final double ukuran;
  final String? label;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/maskot/maskot-$pose.png',
        width: ukuran,
        height: ukuran,
        cacheWidth: (ukuran * 3).round(),
        semanticLabel: label,
        excludeFromSemantics: label == null,
      );
}

({String teks, IconData ikon, Color latar, Color warnaTeks}) gayaStatusGizi(StatusGizi s) => switch (s) {
      StatusGizi.aman => (teks: 'Aman', ikon: Icons.check_rounded, latar: Warna.amanChip, warnaTeks: Colors.white),
      StatusGizi.waspada => (teks: 'Waspada', ikon: Icons.error_outline_rounded, latar: Warna.waspada, warnaTeks: Warna.tinta),
      StatusGizi.tinggi => (teks: 'Tinggi', ikon: Icons.priority_high_rounded, latar: Warna.tinggiChip, warnaTeks: Colors.white),
      StatusGizi.tidakDiketahui => (teks: 'Tidak diketahui', ikon: Icons.help_outline_rounded, latar: Warna.tidakDiketahuiLatar, warnaTeks: Warna.tintaLembut),
    };

/// Chip kecil untuk baris daftar. Selalu ikon + teks, tidak hanya warna.
class ChipStatus extends StatelessWidget {
  const ChipStatus(this.status, {super.key});
  final StatusGizi status;

  @override
  Widget build(BuildContext context) {
    final g = gayaStatusGizi(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: g.latar, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(g.ikon, size: 14, color: g.warnaTeks),
        const SizedBox(width: 4),
        Text(g.teks, style: nunito(12, FontWeight.w800, warna: g.warnaTeks)),
      ]),
    );
  }
}

/// Header aplikasi: kepala Nuri + nama.
class HeaderJeli extends StatelessWidget {
  const HeaderJeli({super.key, this.kanan});
  final Widget? kanan;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(children: [
          const Maskot('01-mengintip', ukuran: 36),
          const SizedBox(width: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Jeli', style: fredoka(21)),
            TextSpan(text: 'Label', style: fredoka(21, warna: Warna.hijauTua)),
          ])),
          const Spacer(),
          ?kanan,
        ]),
      );
}

/// Ikon kemasan sederhana dalam kotak.
class IkonKemasan extends StatelessWidget {
  const IkonKemasan({super.key, this.ukuran = 40});
  final double ukuran;

  @override
  Widget build(BuildContext context) => Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(color: Warna.permukaanRedup, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.local_drink_outlined, size: ukuran * 0.55, color: Warna.tinta),
      );
}
