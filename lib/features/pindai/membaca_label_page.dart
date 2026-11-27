import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';
import 'kontrak_ocr.dart';

/// Layar tunggu pindai. Memakai abstraksi [PemindaiLabel] lewat [AsupanCubit.pindaiLabel].
class MembacaLabelPage extends StatefulWidget {
  const MembacaLabelPage({super.key, this.barcode});

  final String? barcode;

  @override
  State<MembacaLabelPage> createState() => _MembacaLabelPageState();
}

class _MembacaLabelPageState extends State<MembacaLabelPage> {
  Timer? _timer;
  bool _sedangMemindai = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _jalankanPindai);
  }

  Future<void> _jalankanPindai() async {
    if (!mounted || _sedangMemindai) return;
    _sedangMemindai = true;
    final cubit = context.read<AsupanCubit>();
    if (cubit.state.sisaKuota <= 0) {
      context.pushReplacement('/kuota-habis', extra: widget.barcode);
      return;
    }
    final hasil = await cubit.pindaiLabel();
    if (!mounted) return;
    if (hasil.berhasil) {
      final draf = widget.barcode == null ? hasil.draf : hasil.draf!.denganBarcode(widget.barcode);
      context.pushReplacement('/cek', extra: draf);
      return;
    }
    final galat = hasil.galat ?? GalatPindai.internal;
    if (galat == GalatPindai.dibatalkan) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/beranda');
      }
      return;
    }
    if (galat == GalatPindai.resourceExhausted) {
      context.pushReplacement('/kuota-habis', extra: widget.barcode);
      return;
    }
    context.pushReplacement('/tidak-terbaca', extra: (galat: galat, barcode: widget.barcode));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/beranda');
              }
            },
            tooltip: 'Batal',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Jarak.s24, Jarak.s16, Jarak.s24, Jarak.s24),
            children: [
              const Maskot('03-memegang-hp', ukuran: 160, label: 'Nuri memegang HP sambil membaca'),
              const SizedBox(height: Jarak.s16),
              Text('Nuri sedang membaca labelnya...', style: judul(), textAlign: TextAlign.center),
              const SizedBox(height: Jarak.s8),
              Text(
                'Biasanya cuma beberapa detik.',
                style: teksBadan(warna: Warna.tintaLembut),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Jarak.s16),
              Center(
                child: SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Jarak.s4),
                    child: const LinearProgressIndicator(
                      minHeight: Jarak.s8,
                      color: Warna.hijauTua,
                      backgroundColor: Warna.garis,
                      semanticsLabel: 'Membaca label',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Jarak.s32),
              KartuPutih(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Warna.hijauTua),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tips biar makin jeli', style: teksLabel(bobot: FontWeight.w800)),
                      const SizedBox(height: Jarak.s4),
                      Text(
                        'Foto tabel gizi lurus dari depan, tanpa silau lampu, dan jangan terpotong.',
                        style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.5),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
}
