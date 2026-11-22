import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

/// Tampilan informasi paket. Pembelian lewat Google Play Billing menyusul (PRD 14.3, K-10).
class LanggananPage extends StatelessWidget {
  const LanggananPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Jarak.layar, 0, Jarak.layar, Jarak.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Row(children: [
                    const Maskot('05-senang', ukuran: 80, label: 'Nuri senang'),
                    const SizedBox(width: Jarak.s12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s4),
                          decoration: BoxDecoration(
                            color: Warna.oranyeLembut,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Segera hadir',
                            style: teksKecil(bobot: FontWeight.w800, warna: Warna.oranyeTeks),
                          ),
                        ),
                        const SizedBox(height: Jarak.s8),
                        Text('JeliLabel Plus', style: judul(tinggi: 1.15)),
                        const SizedBox(height: Jarak.s4),
                        Text(
                          'Pindai lebih banyak, tanpa iklan. Semua fitur lain tetap gratis.',
                          style: teksLabel(warna: Warna.tintaLembut),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: Jarak.s16),
                  Container(
                    padding: const EdgeInsets.all(Jarak.s16),
                    decoration: BoxDecoration(
                      color: Warna.kartu,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Warna.hijauTua, width: 2),
                      boxShadow: const [BoxShadow(color: Warna.hijauTua, offset: Offset(0, 4))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Jarak.s8,
                        runSpacing: Jarak.s4,
                        children: [
                          Text('Plus', style: judulKecil()),
                          Text('rencana Rp15.000/bulan atau Rp59.900/6 bulan', style: teksLabel(warna: Warna.tintaLembut)),
                        ],
                      ),
                      const SizedBox(height: Jarak.s12),
                      for (final fitur in const [
                        '100 pindai per minggu',
                        'Tanpa video iklan',
                        'Cadangan otomatis ke awan',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: Jarak.s8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.check_rounded, size: 18, color: Warna.hijauTua),
                            const SizedBox(width: Jarak.s8),
                            Expanded(child: Text(fitur, style: teksBadan())),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: Jarak.s16),
                  Container(
                    padding: const EdgeInsets.all(Jarak.s16),
                    decoration: BoxDecoration(
                      color: Warna.permukaanRedup,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gratis, paketmu sekarang', style: teksBadan(bobot: FontWeight.w800)),
                      const SizedBox(height: Jarak.s8),
                      Text(
                        '${AsupanState.kuotaGratisMingguan} pindai per minggu, tambah sampai ${AsupanState.kuotaIklanMingguanMaks} lewat video. Isi manual tanpa batas dan riwayat 7 hari.',
                        style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.5),
                      ),
                    ]),
                  ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TombolTebal.sekunder(label: 'Kembali', onPressed: () => context.pop()),
                const SizedBox(height: Jarak.s8),
                Text(
                  'Belum ada pembelian di versi ini. Harga final diumumkan saat Plus rilis.',
                  style: teksKecil(),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ]),
        ),
      );
}
