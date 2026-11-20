import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

/// Dua keadaan gagal yang bentuknya sama: label tidak terbaca dan kuota habis.
class PindaiGagalPage extends StatefulWidget {
  const PindaiGagalPage.tidakTerbaca({super.key}) : _kuotaHabis = false;
  const PindaiGagalPage.kuotaHabis({super.key}) : _kuotaHabis = true;

  final bool _kuotaHabis;

  @override
  State<PindaiGagalPage> createState() => _PindaiGagalPageState();
}

class _PindaiGagalPageState extends State<PindaiGagalPage> {
  bool _memutarIklan = false;

  Future<void> _tontonIklan() async {
    if (_memutarIklan) return;
    setState(() => _memutarIklan = true);
    final berhasil = await context.read<AsupanCubit>().klaimBonusIklan();
    if (!mounted) return;
    if (berhasil) {
      context.pushReplacement('/pindai');
    } else {
      setState(() => _memutarIklan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Iklan belum selesai ditonton. Kuota belum bertambah.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kuotaHabis = widget._kuotaHabis;
    final state = context.watch<AsupanCubit>().state;
    final sisaSlot = state.sisaSlotIklan;
    final adaSlotIklan = kuotaHabis && sisaSlot > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai Label'),
        leading: IconButton(
          onPressed: _memutarIklan ? null : () => context.pop(),
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
          Maskot(
            kuotaHabis ? '08-tidur' : '04-bingung',
            ukuran: 210,
            label: kuotaHabis ? 'Nuri tidur' : 'Nuri bingung',
          ),
          const SizedBox(height: 12),
          Text(
            kuotaHabis ? 'Nuri istirahat dulu' : 'Label tidak terbaca',
            style: fredoka(24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            kuotaHabis
                ? (adaSlotIklan
                    ? '${AsupanState.kuotaGratisMingguan} pindai gratis minggu ini sudah terpakai. '
                        'Tonton iklan untuk +1 pindai, atau isi manual gratis kapan saja.'
                    : '${AsupanState.kuotaGratisMingguan} pindai gratis + '
                        '${AsupanState.kuotaIklanMingguanMaks} bonus iklan minggu ini sudah terpakai. '
                        'Nuri bangun lagi Senin. Isi manual tetap bisa kapan saja.')
                : 'Pastikan tabel gizi jelas, tidak silau, dan tidak terpotong. Kuota pindaimu tidak berkurang.',
            style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.55),
            textAlign: TextAlign.center,
          ),
          if (kuotaHabis) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Warna.jalurBilah, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  adaSlotIklan
                      ? 'Sisa slot iklan: $sisaSlot dari ${AsupanState.kuotaIklanMingguanMaks}'
                      : 'Sisa pindai: 0 · Slot iklan minggu ini habis',
                  style: nunito(13, FontWeight.w700, warna: Warna.tintaLembut),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (adaSlotIklan) ...[
            TombolTebal(
              label: _memutarIklan ? 'Memutar iklan...' : 'Tonton iklan (+1 pindai)',
              ikon: Icons.play_circle_outline_rounded,
              onPressed: _memutarIklan ? null : _tontonIklan,
            ),
            const SizedBox(height: 12),
            TombolTebal.sekunder(
              label: 'Isi manual',
              onPressed: _memutarIklan ? null : () => context.pushReplacement('/cek', extra: DrafProduk.kosong),
            ),
            const SizedBox(height: 12),
            TombolTebal.sekunder(
              label: 'Lihat JeliLabel Plus',
              ikon: Icons.star_rounded,
              onPressed: _memutarIklan ? null : () => context.pushReplacement('/langganan'),
            ),
          ] else if (kuotaHabis) ...[
            TombolTebal(
              label: 'Isi manual',
              onPressed: () => context.pushReplacement('/cek', extra: DrafProduk.kosong),
            ),
            const SizedBox(height: 12),
            TombolTebal.sekunder(
              label: 'Lihat JeliLabel Plus',
              ikon: Icons.star_rounded,
              onPressed: () => context.pushReplacement('/langganan'),
            ),
          ] else ...[
            TombolTebal(
              label: 'Foto ulang',
              ikon: Icons.photo_camera_outlined,
              onPressed: () => context.pushReplacement('/pindai'),
            ),
            const SizedBox(height: 12),
            TombolTebal.sekunder(
              label: 'Isi manual',
              onPressed: () => context.pushReplacement('/cek', extra: DrafProduk.kosong),
            ),
          ],
        ]),
      ),
    );
  }
}
