import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ambang.dart';
import '../../../core/format.dart';
import '../../../core/theme/tema.dart';
import '../../../core/theme/warna.dart';
import '../../../core/widgets/komponen.dart';
import '../../profil/presentation/profil_cubit.dart';
import '../domain/jenis_tantangan.dart';
import 'tantangan_cubit.dart';

class TantanganPage extends StatefulWidget {
  const TantanganPage({super.key});

  @override
  State<TantanganPage> createState() => _TantanganPageState();
}

class _TantanganPageState extends State<TantanganPage> {
  JenisTantangan? _sedangDimulai;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TantanganCubit>().muat();
    });
  }

  Future<void> _mulai(JenisTantangan jenis) async {
    final cubit = context.read<TantanganCubit>();
    if (cubit.state.menyimpan || cubit.state.adaBerjalan) return;
    setState(() => _sedangDimulai = jenis);
    final ok = await cubit.mulai(jenis);
    if (!mounted) return;
    setState(() => _sedangDimulai = null);
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(cubit.state.galat ?? 'Gagal memulai tantangan.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Tantangan'),
          leading: IconButton(
            onPressed: () => context.pop(),
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<TantanganCubit, TantanganState>(
            builder: (context, state) {
              final batas = context.watch<ProfilCubit>().state.batas;
              final berjalan = state.berjalan;
              final berakhir = state.berakhirTerbaru;
              return ListView(
                padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s8, Jarak.layar, Jarak.s24),
                children: [
                  if (state.galat != null && berjalan == null && state.lencana.isEmpty) ...[
                    KartuPutih(
                      child: Text(state.galat!, style: teksBadan(warna: Warna.tinggiChip)),
                    ),
                    const SizedBox(height: Jarak.s16),
                  ],
                  if (berjalan != null) ...[
                    _KartuBerjalan(kemajuan: berjalan, batas: batas),
                    const SizedBox(height: Jarak.s20),
                  ] else if (berakhir != null) ...[
                    _KartuBerakhir(kemajuan: berakhir),
                    const SizedBox(height: Jarak.s20),
                  ],
                  Text('Pilih tantangan berikutnya', style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s12),
                  for (final (i, jenis) in JenisTantangan.values.indexed) ...[
                    if (i > 0) const SizedBox(height: Jarak.s12),
                    _KartuPilihan(
                      jenis: jenis,
                      batas: batas,
                      aktif: !state.adaBerjalan && !state.menyimpan,
                      memuat: state.menyimpan && _sedangDimulai == jenis,
                      onMulai: () => _mulai(jenis),
                    ),
                  ],
                  const SizedBox(height: Jarak.s24),
                  Text('Lencana', style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s12),
                  if (state.lencana.isEmpty)
                    KartuPutih(
                      child: Text(
                        'Belum ada lencana. Selesaikan satu tantangan untuk mendapatkannya.',
                        style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
                      ),
                    )
                  else
                    for (final (i, item) in state.lencana.indexed) ...[
                      if (i > 0) const SizedBox(height: Jarak.s12),
                      _KartuLencana(item: item),
                    ],
                ],
              );
            },
          ),
        ),
      );
}

class _KartuBerjalan extends StatelessWidget {
  const _KartuBerjalan({required this.kemajuan, required this.batas});

  final KemajuanTantangan kemajuan;
  final BatasHarian batas;

  @override
  Widget build(BuildContext context) => Material(
        color: Warna.oranyeMuda,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Warna.oranye, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(Jarak.s16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Warna.oranyeTepi, width: Jarak.s4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'BERJALAN · sisa ${kemajuan.sisaHari} hari',
                      style: teksKecil(bobot: FontWeight.w800, warna: Warna.oranyeTeks),
                    ),
                  ),
                  Text(
                    '${kemajuan.terpenuhi}/${kemajuan.target}',
                    style: judulKecil(),
                  ),
                ],
              ),
              const SizedBox(height: Jarak.s8),
              Text(kemajuan.jenis.judul, style: judulKecil(tinggi: 1.2)),
              const SizedBox(height: Jarak.s4),
              Text(
                kemajuan.jenis.keteranganUntuk(batas),
                style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.35),
              ),
              const SizedBox(height: Jarak.s12),
              Row(
                children: [
                  for (final (i, hari) in kemajuan.tujuhHari.indexed) ...[
                    if (i > 0) const SizedBox(width: Jarak.s4),
                    Expanded(child: _TitikHari(hari: hari)),
                  ],
                ],
              ),
              const SizedBox(height: Jarak.s12),
              const _LegendaTitik(),
            ],
          ),
        ),
      );
}

class _LegendaTitik extends StatelessWidget {
  const _LegendaTitik();

  @override
  Widget build(BuildContext context) {
    const item = <(StatusHariTantangan, String)>[
      (StatusHariTantangan.berhasil, 'Berhasil'),
      (StatusHariTantangan.belum, 'Belum berhasil'),
      (StatusHariTantangan.mendatang, 'Hari mendatang'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Jarak.s12,
      runSpacing: Jarak.s8,
      children: [
        for (final (status, label) in item)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BulatanHari(status: status, ukuran: 18),
              const SizedBox(width: Jarak.s4),
              Text(label, style: teksKecil(bobot: FontWeight.w700)),
            ],
          ),
      ],
    );
  }
}

class _BulatanHari extends StatelessWidget {
  const _BulatanHari({required this.status, this.ukuran = 28});

  final StatusHariTantangan status;
  final double ukuran;

  @override
  Widget build(BuildContext context) => switch (status) {
        StatusHariTantangan.berhasil => Container(
            width: ukuran,
            height: ukuran,
            decoration: BoxDecoration(
              color: Warna.oranye,
              shape: BoxShape.circle,
              border: Border.all(color: Warna.oranyeTepi, width: ukuran >= 24 ? 2 : 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check_rounded, size: ukuran * 0.58, color: Warna.tinta),
          ),
        StatusHariTantangan.belum => Container(
            width: ukuran,
            height: ukuran,
            decoration: BoxDecoration(
              color: Warna.kartu,
              shape: BoxShape.circle,
              border: Border.all(color: Warna.garis, width: ukuran >= 24 ? 2 : 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '·',
              style: teksLabel(bobot: FontWeight.w800, warna: Warna.tintaLembut, tinggi: 1),
            ),
          ),
        StatusHariTantangan.mendatang => CustomPaint(
            size: Size.square(ukuran),
            painter: _LingkaranPutusPainter(lebarGaris: ukuran >= 24 ? 2 : 1.5),
          ),
      };
}

class _TitikHari extends StatelessWidget {
  const _TitikHari({required this.hari});

  final HariTantangan hari;

  @override
  Widget build(BuildContext context) {
    final labelStatus = switch (hari.status) {
      StatusHariTantangan.berhasil => 'berhasil',
      StatusHariTantangan.belum => 'belum berhasil',
      StatusHariTantangan.mendatang => 'hari mendatang',
    };
    final namaHari = hariSingkat(hari.tanggal);

    return Semantics(
      label: '$namaHari: $labelStatus',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BulatanHari(status: hari.status),
          const SizedBox(height: Jarak.s4),
          Text(
            namaHari,
            style: teksKecil(bobot: FontWeight.w700, warna: Warna.tintaLembut),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _LingkaranPutusPainter extends CustomPainter {
  const _LingkaranPutusPainter({this.lebarGaris = 2});

  final double lebarGaris;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - (lebarGaris / 2);
    final fillPaint = Paint()
      ..color = Warna.kartu
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    final strokePaint = Paint()
      ..color = Warna.garisBatas
      ..style = PaintingStyle.stroke
      ..strokeWidth = lebarGaris;

    const jumlahSegmen = 8;
    const step = (2 * math.pi) / jumlahSegmen;
    const panjang = step * 0.55;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < jumlahSegmen; i++) {
      canvas.drawArc(rect, i * step, panjang, false, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LingkaranPutusPainter oldDelegate) =>
      oldDelegate.lebarGaris != lebarGaris;
}

class _KartuBerakhir extends StatelessWidget {
  const _KartuBerakhir({required this.kemajuan});

  final KemajuanTantangan kemajuan;

  @override
  Widget build(BuildContext context) => KartuPutih(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kemajuan.jenis.judul, style: teksBadan(bobot: FontWeight.w800)),
            const SizedBox(height: Jarak.s4),
            Text(
              'Tantangan selesai. Coba lagi kapan saja.',
              style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut),
            ),
            const SizedBox(height: Jarak.s4),
            Text(
              '${kemajuan.terpenuhi} dari ${kemajuan.target} hari tercapai',
              style: teksKecil(),
            ),
          ],
        ),
      );
}

class _KartuPilihan extends StatelessWidget {
  const _KartuPilihan({
    required this.jenis,
    required this.batas,
    required this.aktif,
    required this.memuat,
    required this.onMulai,
  });

  final JenisTantangan jenis;
  final BatasHarian batas;
  final bool aktif;
  final bool memuat;
  final VoidCallback onMulai;

  @override
  Widget build(BuildContext context) => KartuPutih(
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jenis.judul, style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s4),
                  Text(
                    jenis.keteranganUntuk(batas),
                    style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Jarak.s12),
            Semantics(
              button: true,
              enabled: aktif,
              label: 'Mulai ${jenis.judul}',
              excludeSemantics: true,
              child: Material(
                color: aktif ? Warna.hijauTua : Warna.jalurBilah,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: aktif ? onMulai : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
                    padding: const EdgeInsets.symmetric(horizontal: Jarak.s16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: aktif ? Warna.hijauTepi : Warna.garis,
                          width: 3,
                        ),
                      ),
                    ),
                    child: memuat
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Warna.tintaLembut),
                          )
                        : Text(
                            'Mulai',
                            style: teksLabel(
                              bobot: FontWeight.w800,
                              warna: aktif ? Warna.kartu : Warna.tintaLembut,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _KartuLencana extends StatelessWidget {
  const _KartuLencana({required this.item});

  final LencanaTantangan item;

  static IconData _ikon(JenisTantangan jenis) => switch (jenis) {
        JenisTantangan.gula5 => Icons.local_cafe_outlined,
        JenisTantangan.natrium5 => Icons.soup_kitchen_outlined,
        JenisTantangan.lemak5 => Icons.restaurant_outlined,
        JenisTantangan.catat7 => Icons.edit_calendar_outlined,
      };

  @override
  Widget build(BuildContext context) => KartuPutih(
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Warna.oranyeMuda,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Warna.oranye, width: 1.5),
              ),
              child: Icon(_ikon(item.jenis), color: Warna.oranyeTeks, size: 24),
            ),
            const SizedBox(width: Jarak.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.jenis.judul, style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s4),
                  Text(
                    'Selesai ${tanggalSingkat(item.tanggalSelesai)}',
                    style: teksLabel(warna: Warna.tintaLembut),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
