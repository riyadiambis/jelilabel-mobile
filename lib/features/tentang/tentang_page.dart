import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';

class TentangPage extends StatelessWidget {
  const TentangPage({super.key});

  @override
  Widget build(BuildContext context) {
    void segera() =>
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Segera hadir')));

    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
      const Maskot('01-mengintip', ukuran: 140, label: 'Nuri, maskot JeliLabel'),
      Center(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Jeli', style: fredoka(26)),
          TextSpan(text: 'Label', style: fredoka(26, warna: Warna.hijauTua)),
        ])),
      ),
      Center(child: Text('Versi 1.0.0 · Ofi Labs', style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut))),
      const SizedBox(height: 16),
      KartuPutih(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Acuan batas harian', style: fredoka(17)),
          const SizedBox(height: 6),
          Text(
            'Kemenkes RI (Permenkes No. 30 Tahun 2013): gula 50 g dan natrium 2000 mg per hari untuk orang dewasa.',
            style: nunito(14, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.5),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
        decoration: BoxDecoration(
          color: Warna.amanLatar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Warna.aman, width: 2),
          boxShadow: const [BoxShadow(color: Warna.aman, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          const Maskot('09-perisai', ukuran: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bukan saran medis', style: fredoka(17)),
              const SizedBox(height: 2),
              Text(
                'JeliLabel membantu memantau. Hasil baca AI bisa keliru, jadi cocokkan dengan label. Untuk diet khusus, tanya dokter.',
                style: nunito(13, FontWeight.w400, tinggi: 1.45),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      KartuPutih(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          _Tautan('Paket dan langganan', () => context.push('/langganan')),
          const Divider(height: 1, color: Warna.jalurBilah),
          _Tautan('Kebijakan privasi', segera),
          const Divider(height: 1, color: Warna.jalurBilah),
          _Tautan('Hubungi Ofi Labs', segera),
        ]),
      ),
    ]);
  }
}

class _Tautan extends StatelessWidget {
  const _Tautan(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 52,
        title: Text(label, style: nunito(15, FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
        onTap: onTap,
      );
}
