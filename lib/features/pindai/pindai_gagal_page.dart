import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

/// Dua keadaan gagal yang bentuknya sama: label tidak terbaca dan kuota habis.
class PindaiGagalPage extends StatelessWidget {
  const PindaiGagalPage.tidakTerbaca({super.key}) : _kuotaHabis = false;
  const PindaiGagalPage.kuotaHabis({super.key}) : _kuotaHabis = true;

  final bool _kuotaHabis;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Pindai Label'),
          leading: IconButton(onPressed: () => context.pop(), tooltip: 'Kembali', icon: const Icon(Icons.arrow_back_rounded)),
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
            Maskot(_kuotaHabis ? '08-tidur' : '04-bingung',
                ukuran: 210, label: _kuotaHabis ? 'Nuri tidur' : 'Nuri bingung'),
            const SizedBox(height: 12),
            Text(_kuotaHabis ? 'Nuri istirahat dulu' : 'Label tidak terbaca',
                style: fredoka(24), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              _kuotaHabis
                  ? '${AsupanState.kuotaGratisMingguan} pindai gratis minggu ini sudah terpakai. '
                      'Nuri bangun lagi Senin. Isi manual tetap bisa kapan saja.'
                  : 'Pastikan tabel gizi jelas, tidak silau, dan tidak terpotong. Kuota pindaimu tidak berkurang.',
              style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.55),
              textAlign: TextAlign.center,
            ),
            if (_kuotaHabis) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Warna.jalurBilah, borderRadius: BorderRadius.circular(999)),
                  child: Text('Sisa pindai: 0 dari ${AsupanState.kuotaGratisMingguan}',
                      style: nunito(13, FontWeight.w700, warna: Warna.tintaLembut)),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_kuotaHabis)
              TombolTebal(label: 'Isi manual', onPressed: () => context.pushReplacement('/cek', extra: DrafProduk.kosong))
            else
              TombolTebal(
                  label: 'Foto ulang',
                  ikon: Icons.photo_camera_outlined,
                  onPressed: () => context.pushReplacement('/pindai')),
            const SizedBox(height: 12),
            if (_kuotaHabis)
              TombolTebal.sekunder(
                  label: 'Lihat JeliLabel Plus',
                  ikon: Icons.star_rounded,
                  onPressed: () => context.pushReplacement('/langganan'))
            else
              TombolTebal.sekunder(
                  label: 'Isi manual', onPressed: () => context.pushReplacement('/cek', extra: DrafProduk.kosong)),
          ]),
        ),
      );
}
