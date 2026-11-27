import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';
import 'kontrak_ocr.dart';

/// Layar gagal pindai: kuota habis, label tidak terbaca, server sibuk, atau galat jaringan.
class PindaiGagalPage extends StatefulWidget {
  const PindaiGagalPage.tidakTerbaca({super.key, this.galat, this.barcode}) : _kuotaHabis = false;
  const PindaiGagalPage.kuotaHabis({super.key, this.barcode})
      : _kuotaHabis = true,
        galat = null;

  final bool _kuotaHabis;
  final GalatPindai? galat;
  final String? barcode;

  @override
  State<PindaiGagalPage> createState() => _PindaiGagalPageState();
}

Object? _bacaExtraGalat(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  try {
    final extra = GoRouterState.of(context).extra;
    if (extra is ({GalatPindai galat, String? barcode})) return extra.galat;
    return extra;
  } catch (_) {
    return null;
  }
}

class _PindaiGagalPageState extends State<PindaiGagalPage> {
  bool _memutarIklan = false;

  DrafProduk get _drafManual =>
      widget.barcode == null ? DrafProduk.kosong : DrafProduk(nama: '', barcode: widget.barcode);

  Future<void> _tontonIklan() async {
    if (_memutarIklan) return;
    setState(() => _memutarIklan = true);
    final berhasil = await context.read<AsupanCubit>().klaimBonusIklan();
    if (!mounted) return;
    if (berhasil) {
      context.pushReplacement('/pindai', extra: widget.barcode);
    } else {
      setState(() => _memutarIklan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Video belum selesai. Kuota tidak bertambah.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kuotaHabis = widget._kuotaHabis;
    final extraGalat = _bacaExtraGalat(context);
    final galat = widget.galat ?? (extraGalat is GalatPindai ? extraGalat : GalatPindai.tidakTerbaca);
    final adalahTidakTerbaca = galat == GalatPindai.tidakTerbaca || galat == GalatPindai.invalidArgument;
    final adalahSibuk = galat == GalatPindai.sibuk;
    final state = context.watch<AsupanCubit>().state;
    final sisaSlot = state.sisaSlotIklan;
    final adaSlotIklan = kuotaHabis && sisaSlot > 0;

    final String pose;
    final String labelMaskot;
    final String judulLayar;
    final String pesan;
    final String infoPil;

    if (kuotaHabis) {
      pose = '08-tidur';
      labelMaskot = 'Nuri tidur';
      judulLayar = 'Nuri istirahat dulu';
      pesan = adaSlotIklan
          ? '${AsupanState.kuotaGratisMingguan} pindai gratis minggu ini sudah terpakai. '
              'Tonton satu video untuk tambah 1 pindai, atau isi manual kapan saja.'
          : 'Batas ${AsupanState.kuotaIklanMingguanMaks} bonus iklan minggu ini sudah tercapai. '
              'Isi manual tetap bisa kapan saja.';
      infoPil = 'Bonus video: ${state.bonusIklanDipakai} dari ${AsupanState.kuotaIklanMingguanMaks} minggu ini';
    } else if (adalahTidakTerbaca) {
      pose = '04-bingung';
      labelMaskot = 'Nuri bingung';
      judulLayar = 'Label tidak terbaca';
      pesan = 'Foto tabel gizi lurus dari depan, tanpa silau, dan jangan terpotong.';
      infoPil = 'Kuota pindaimu tidak berkurang';
    } else if (adalahSibuk) {
      pose = '04-bingung';
      labelMaskot = 'Nuri bingung';
      judulLayar = 'Nuri lagi sibuk';
      pesan = 'Nuri sedang sibuk, coba lagi sebentar';
      infoPil = 'Kuota pindaimu tidak berkurang';
    } else {
      pose = '08-tidur';
      labelMaskot = 'Nuri tidur';
      judulLayar = 'Tidak ada internet';
      pesan = 'Nuri butuh internet untuk membaca label. Periksa koneksi, lalu coba lagi.';
      infoPil = 'Kuota pindaimu tidak berkurang';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _memutarIklan ? null : () => context.canPop() ? context.pop() : context.go('/beranda'),
          tooltip: 'Kembali',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Maskot(pose, ukuran: 144, label: labelMaskot),
                          const SizedBox(height: Jarak.s16),
                          Text(judulLayar, style: judul(), textAlign: TextAlign.center),
                          const SizedBox(height: Jarak.s12),
                          Text(
                            pesan,
                            style: teksBadan(warna: Warna.tintaLembut, tinggi: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Jarak.s16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s8),
                            decoration: BoxDecoration(
                              color: Warna.jalurBilah,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              infoPil,
                              style: teksLabel(bobot: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (adaSlotIklan) ...[
                    TombolTebal(
                      label: 'Tonton video, +1 pindai',
                      ikon: Icons.play_arrow_rounded,
                      memuat: _memutarIklan,
                      onPressed: _memutarIklan ? null : _tontonIklan,
                    ),
                    const SizedBox(height: Jarak.s12),
                    TombolTebal.sekunder(
                      label: 'Isi manual',
                      onPressed: _memutarIklan ? null : () => context.pushReplacement('/cek', extra: _drafManual),
                    ),
                    const SizedBox(height: Jarak.s4),
                    TextButton(
                      onPressed: _memutarIklan ? null : () => context.pushReplacement('/langganan'),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(
                        'Tentang JeliLabel Plus',
                        style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua),
                      ),
                    ),
                  ] else if (kuotaHabis) ...[
                    TombolTebal(
                      label: 'Isi manual',
                      onPressed: () => context.pushReplacement('/cek', extra: _drafManual),
                    ),
                    const SizedBox(height: Jarak.s4),
                    TextButton(
                      onPressed: () => context.pushReplacement('/langganan'),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(
                        'Tentang JeliLabel Plus',
                        style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua),
                      ),
                    ),
                  ] else ...[
                    TombolTebal(
                      label: (adalahTidakTerbaca || adalahSibuk) ? 'Foto ulang' : 'Coba lagi',
                      ikon: (adalahTidakTerbaca || adalahSibuk)
                          ? Icons.photo_camera_outlined
                          : Icons.refresh_rounded,
                      onPressed: () => context.pushReplacement('/pindai', extra: widget.barcode),
                    ),
                    const SizedBox(height: Jarak.s12),
                    TombolTebal.sekunder(
                      label: 'Isi manual',
                      onPressed: () => context.pushReplacement('/cek', extra: _drafManual),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
