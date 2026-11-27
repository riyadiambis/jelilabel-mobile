import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Lembar konfirmasi "Tercatat!" yang menutup otomatis setelah 2 detik.
Future<void> tampilkanLembarTercatat(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Warna.kartu,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _LembarTercatat(),
    );

/// Lembar perayaan saat tantangan selesai dicapai (Nuri pose 05).
Future<void> tampilkanLembarTantanganTercapai(BuildContext context, String judulTantangan) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Warna.kartu,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Jarak.s24, Jarak.s20, Jarak.s24, Jarak.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Maskot('05-senang', ukuran: 104, label: 'Nuri senang')),
              const SizedBox(height: Jarak.s12),
              Text('Tantangan tercapai!', style: judul(), textAlign: TextAlign.center),
              const SizedBox(height: Jarak.s4),
              Text(
                judulTantangan,
                style: teksBadan(bobot: FontWeight.w700, warna: Warna.tintaLembut),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Jarak.s20),
              TombolTebal(label: 'Tutup', onPressed: () => Navigator.of(c).pop()),
            ],
          ),
        ),
      ),
    );

class _LembarTercatat extends StatefulWidget {
  const _LembarTercatat();

  @override
  State<_LembarTercatat> createState() => _LembarTercatatState();
}

class _LembarTercatatState extends State<_LembarTercatat> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      // Pengguna bisa menutup lembar sendiri tepat sebelum 2 detik; jangan pop rute di bawahnya.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Jarak.s24, Jarak.s24, Jarak.s24, Jarak.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Maskot('05-senang', ukuran: 120, label: 'Nuri senang')),
            const SizedBox(height: Jarak.s12),
            Text('Tercatat!', style: judul(), textAlign: TextAlign.center),
            const SizedBox(height: Jarak.s4),
            Text(
              'Asupan hari ini sudah diperbarui.',
              style: teksLabel(warna: Warna.tintaLembut),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

/// Dialog pilih porsi ½, 1, 2, atau Lain (maksimal 20 sajian).
Future<double?> tampilkanDialogPorsi(
  BuildContext context, {
  String judulDialog = 'Pilih porsi',
  double porsiAwal = 1,
  String labelSimpan = 'Simpan',
}) =>
    showDialog<double>(
      context: context,
      builder: (_) => _DialogPilihPorsi(
        judulDialog: judulDialog,
        porsiAwal: porsiAwal,
        labelSimpan: labelSimpan,
      ),
    );

class _DialogPilihPorsi extends StatefulWidget {
  const _DialogPilihPorsi({
    required this.judulDialog,
    required this.porsiAwal,
    required this.labelSimpan,
  });

  final String judulDialog;
  final double porsiAwal;
  final String labelSimpan;

  @override
  State<_DialogPilihPorsi> createState() => _DialogPilihPorsiState();
}

class _DialogPilihPorsiState extends State<_DialogPilihPorsi> {
  late String _pilihan;
  late double _porsi;
  late final TextEditingController _c;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _porsi = widget.porsiAwal;
    if (widget.porsiAwal == 0.5) {
      _pilihan = '½';
      _c = TextEditingController();
    } else if (widget.porsiAwal == 1.0) {
      _pilihan = '1';
      _c = TextEditingController();
    } else if (widget.porsiAwal == 2.0) {
      _pilihan = '2';
      _c = TextEditingController();
    } else {
      _pilihan = 'lain';
      _c = TextEditingController(text: angka(widget.porsiAwal));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_pilihan != 'lain') {
      Navigator.pop(context, _porsi);
      return;
    }
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 20) {
      setState(() => _galat = 'Isi angka lebih dari 0, maksimal 20');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    const pilihan = <(String, double)>[
      ('½', 0.5),
      ('1', 1),
      ('2', 2),
    ];
    return AlertDialog(
      title: Text(widget.judulDialog, style: judulKecil()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final (label, nilai) in pilihan) ...[
                  Expanded(
                    child: _TombolPorsiDialog(
                      label: label,
                      terpilih: _pilihan == label,
                      onTap: () => setState(() {
                        _pilihan = label;
                        _porsi = nilai;
                        _galat = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: Jarak.s8),
                ],
                Expanded(
                  child: _TombolPorsiDialog(
                    label: 'Lain',
                    terpilih: _pilihan == 'lain',
                    onTap: () => setState(() => _pilihan = 'lain'),
                  ),
                ),
              ],
            ),
            if (_pilihan == 'lain') ...[
              const SizedBox(height: Jarak.s12),
              TextField(
                controller: _c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: 'Jumlah sajian',
                  hintText: 'mis. 1,5',
                  errorText: _galat,
                  errorMaxLines: 2,
                ),
                onSubmitted: (_) => _simpan(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _simpan, child: Text(widget.labelSimpan)),
      ],
    );
  }
}

class _TombolPorsiDialog extends StatelessWidget {
  const _TombolPorsiDialog({required this.label, required this.terpilih, required this.onTap});
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: terpilih,
        button: true,
        child: Material(
          color: terpilih ? Warna.oranyeLembut : Warna.kartu,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: terpilih ? Warna.oranye : Warna.garis, width: terpilih ? 2 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                    child: Text(label, style: teksLabel(bobot: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
