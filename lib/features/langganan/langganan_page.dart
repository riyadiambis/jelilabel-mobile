import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

/// Tampilan paket saja. Pembelian lewat Google Play Billing menyusul (PRD 14.3, K-10).
class LanggananPage extends StatelessWidget {
  const LanggananPage({super.key});

  void _segera(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Langganan segera hadir')));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => context.pop(), tooltip: 'Tutup', icon: const Icon(Icons.close_rounded)),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
                Row(children: [
                  const Maskot('05-senang', ukuran: 92, label: 'Nuri mengacungkan jempol'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pantau lebih dalam bareng Nuri', style: fredoka(22, tinggi: 1.25)),
                      const SizedBox(height: 4),
                      Text('Memantau gula dan natrium harian tetap gratis selamanya.',
                          style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                KartuPutih(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Gratis', style: fredoka(16)),
                        Text('${AsupanState.kuotaGratisMingguan} pindai gratis per minggu · tambah lewat iklan · isi manual tanpa batas',
                            style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut)),
                        const SizedBox(height: 2),
                        Text('1 video = +1 pindai, maksimal ${AsupanState.kuotaIklanMingguanMaks} video/minggu',
                            style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Warna.jalurBilah, borderRadius: BorderRadius.circular(999)),
                      child: Text('Paket kamu', style: nunito(12, FontWeight.w700, warna: Warna.tintaLembut)),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    decoration: BoxDecoration(
                      color: Warna.kartu,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Warna.hijauTua, width: 2.5),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _Harga(nama: 'Plus', harga: 'Rp15.000'),
                      const SizedBox(height: 10),
                      for (final m in const [
                        '100 pindai per minggu',
                        'Grafik 30 dan 90 hari, laporan PDF mingguan',
                        'Batas pribadi dan mode Pantau Diabetes',
                        'Koleksi kostum Nuri',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.check_rounded, size: 18, color: Warna.hijauTua),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m, style: nunito(14, FontWeight.w600))),
                          ]),
                        ),
                    ]),
                  ),
                  Positioned(
                    top: -12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Warna.hijauTua, borderRadius: BorderRadius.circular(999)),
                      child: Text('Paling pas', style: fredoka(12, warna: Colors.white)),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                KartuPutih(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _Harga(nama: 'Keluarga', harga: 'Rp49.000'),
                    const SizedBox(height: 6),
                    Text('Semua isi Plus untuk hingga 5 orang, 250 pindai per minggu dipakai bersama, laporan per anggota.',
                        style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.5)),
                  ]),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.garis))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TombolTebal(label: 'Coba Plus', onPressed: () => _segera(context)),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Tagihan lewat Google Play. Batalkan kapan saja.',
                        style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut)),
                    TextButton(
                      onPressed: () => _segera(context),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text('Pulihkan pembelian', style: nunito(13, FontWeight.w700, warna: Warna.hijauTua)),
                    ),
                  ],
                ),
              ]),
            ),
          ]),
        ),
      );
}

class _Harga extends StatelessWidget {
  const _Harga({required this.nama, required this.harga});
  final String nama;
  final String harga;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text(nama, style: fredoka(18))),
        Text(harga, style: fredoka(20)),
        Text('/bulan', style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut)),
      ]);
}
