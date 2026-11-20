import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

/// Simulasi pindai (ISSUE-01). ML Kit dan Gemini menyusul di v0.3.
class MembacaLabelPage extends StatefulWidget {
  const MembacaLabelPage({super.key});

  @override
  State<MembacaLabelPage> createState() => _MembacaLabelPageState();
}

class _MembacaLabelPageState extends State<MembacaLabelPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final cubit = context.read<AsupanCubit>();
      if (cubit.state.sisaKuota <= 0) {
        context.pushReplacement('/kuota-habis');
        return;
      }
      final draf = cubit.pindaiSimulasi();
      if (draf == null) {
        context.pushReplacement('/tidak-terbaca');
      } else {
        context.pushReplacement('/cek', extra: draf);
      }
    });
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
            onPressed: () => context.pop(),
            tooltip: 'Batal',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
            const Maskot('03-memegang-hp', ukuran: 220, label: 'Nuri memegang HP sambil membaca'),
            const SizedBox(height: 14),
            Text('Nuri sedang membaca labelnya...', style: fredoka(24), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Biasanya cuma beberapa detik.',
                style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                      minHeight: 8, color: Warna.hijauTua, backgroundColor: Warna.garis, semanticsLabel: 'Membaca label'),
                ),
              ),
            ),
            const SizedBox(height: 40),
            KartuPutih(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Warna.hijauTua),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tips biar makin jeli', style: nunito(14, FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Foto tabel gizi lurus dari depan, tanpa silau lampu, dan jangan terpotong.',
                        style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.5)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
}
