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
    this.memuat = false,
    this.warna = Warna.hijauTua,
    this.tepi = Warna.hijauTepi,
    this.warnaTeks = Warna.kartu,
    this.tinggi = 52,
    this.teksJudul = true,
  });

  /// Tombol Pindai: oranye, teks tinta (teks putih di atas oranye dilarang).
  const TombolTebal.pindai({super.key, required this.label, required this.onPressed, this.ikon})
      : memuat = false,
        warna = Warna.oranye,
        tepi = Warna.oranyeTepi,
        warnaTeks = Warna.tinta,
        tinggi = 56,
        teksJudul = true;

  /// Tombol sekunder: putih bergaris.
  const TombolTebal.sekunder({
    super.key,
    required this.label,
    required this.onPressed,
    this.ikon,
    this.tinggi = 52,
  })  : memuat = false,
        warna = Warna.kartu,
        tepi = Warna.garis,
        warnaTeks = Warna.tinta,
        teksJudul = false;

  /// Tombol bahaya: merah lembut bergaris, untuk aksi buang/hapus.
  const TombolTebal.bahaya({super.key, required this.label, required this.onPressed, this.ikon})
      : memuat = false,
        warna = Warna.bahayaLatar,
        tepi = Warna.bahayaGaris,
        warnaTeks = Warna.tinggiChip,
        tinggi = 52,
        teksJudul = false;

  final String label;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final bool memuat;
  final Color warna;
  final Color tepi;
  final Color warnaTeks;
  final double tinggi;
  final bool teksJudul;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    final bergaris = warna == Warna.kartu || warna == Warna.bahayaLatar;
    final warnaTeksTampil = aktif ? warnaTeks : Warna.tintaLembut;
    final gayaTeks = teksJudul
        ? judulKecil(warna: warnaTeksTampil)
        : teksBadan(bobot: FontWeight.w800, warna: warnaTeksTampil);
    return Semantics(
      button: true,
      enabled: aktif,
      child: Material(
        color: aktif ? warna : Warna.jalurBilah,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: bergaris ? BorderSide(color: aktif ? tepi : Warna.garis, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: tinggi,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: aktif ? tepi : Warna.garis, width: Jarak.s4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s16),
            // FittedBox: label panjang mengecil di layar sempit, tetap aman di dalam Row lain.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (memuat) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: warnaTeksTampil,
                      ),
                    ),
                    const SizedBox(width: Jarak.s8),
                  ] else if (ikon != null) ...[
                    Icon(ikon, color: warnaTeksTampil, size: 20),
                    const SizedBox(width: Jarak.s8),
                  ],
                  Text(label, style: gayaTeks, maxLines: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu-tombol utama untuk memindai label gizi (UI-GUIDE: paling menonjol).
class TombolPindai extends StatelessWidget {
  const TombolPindai({
    super.key,
    required this.onPressed,
    this.subjudul = 'Foto tabel gizi di kemasan',
  });

  final VoidCallback? onPressed;
  final String subjudul;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    return Semantics(
      button: true,
      enabled: aktif,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: aktif
              ? [BoxShadow(color: Warna.oranye.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))]
              : const [],
        ),
        child: Material(
          color: aktif ? Warna.oranye : Warna.garis,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: aktif ? Warna.oranyeTepi : Warna.garis, width: 6)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: Warna.kartu, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera_outlined, color: Warna.tinta, size: 26),
                  ),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pindai Label Gizi',
                          style: judulKecil(tinggi: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subjudul,
                          style: teksLabel(bobot: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Jarak.s8),
                  const Icon(Icons.chevron_right_rounded, color: Warna.tinta, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu putih dengan bayangan bawah tipis.
class KartuPutih extends StatelessWidget {
  const KartuPutih({super.key, required this.child, this.padding = const EdgeInsets.all(Jarak.s16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Warna.garis),
          boxShadow: const [BoxShadow(color: Warna.garisBayangan, offset: Offset(0, 3))],
        ),
        child: child,
      );
}

class Maskot extends StatelessWidget {
  const Maskot(this.pose, {super.key, this.ukuran = 160, this.label});

  /// Nama berkas tanpa awalan, mis. '01-mengintip'.
  final String pose;
  final double ukuran;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tampil = ukuran > 160 ? 160.0 : ukuran;
    return Image.asset(
      'assets/maskot/maskot-$pose.png',
      width: tampil,
      height: tampil,
      cacheWidth: (tampil * 3).round(),
      semanticLabel: label,
      excludeFromSemantics: label == null,
    );
  }
}

({String teks, IconData ikon, Color latar, Color warnaTeks}) gayaStatusGizi(StatusGizi s) => switch (s) {
      StatusGizi.aman => (teks: 'Aman', ikon: Icons.check_rounded, latar: Warna.amanLatar, warnaTeks: Warna.amanChip),
      StatusGizi.waspada => (teks: 'Waspada', ikon: Icons.error_outline_rounded, latar: Warna.waspadaLatar, warnaTeks: Warna.waspadaChip),
      StatusGizi.tinggi => (teks: 'Tinggi', ikon: Icons.priority_high_rounded, latar: Warna.tinggiLatar, warnaTeks: Warna.tinggiChip),
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
      padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s4),
      decoration: BoxDecoration(color: g.latar, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(g.ikon, size: 14, color: g.warnaTeks),
        const SizedBox(width: Jarak.s4),
        Text(g.teks, style: teksKecil(bobot: FontWeight.w800, warna: g.warnaTeks)),
      ]),
    );
  }
}

/// Ikon kemasan sederhana dalam kotak.
class IkonKemasan extends StatelessWidget {
  const IkonKemasan({super.key, this.ukuran = 44});
  final double ukuran;

  @override
  Widget build(BuildContext context) => Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(color: Warna.permukaanRedup, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.local_drink_outlined, size: ukuran * 0.5, color: Warna.tinta),
      );
}
