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
          const SnackBar(content: Text('Video belum selesai. Kuota tidak bertambah.')),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Maskot(
                kuotaHabis ? '08-tidur' : '04-bingung',
                ukuran: 120,
                label: kuotaHabis ? 'Nuri tidur' : 'Nuri bingung',
              ),
              const SizedBox(height: 8),
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
                            'Tonton satu video untuk +1 pindai, atau isi manual kapan saja.'
                        : 'Batas ${AsupanState.kuotaIklanMingguanMaks} bonus iklan minggu ini sudah tercapai. '
                            'Isi manual tetap bisa kapan saja.')
                    : 'Pastikan tabel gizi jelas, tidak silau, dan tidak terpotong. Kuota pindaimu tidak berkurang.',
                style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.5),
                textAlign: TextAlign.center,
              ),
              if (kuotaHabis) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Warna.jalurBilah, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sisa pindai: 0 dari ${state.plafonKuota}',
                          style: nunito(13, FontWeight.w700, warna: Warna.tinta),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bonus iklan: ${state.bonusIklanDipakai} dari ${AsupanState.kuotaIklanMingguanMaks} minggu ini',
                          style: nunito(12, FontWeight.w600, warna: Warna.tintaLembut),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (adaSlotIklan) ...[
                TombolTebal(
                  label: 'Tonton iklan (+1 pindai)',
                  ikon: Icons.play_circle_outline_rounded,
                  memuat: _memutarIklan,
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
            ],
          ),
        ),
      ),
    );
  }
}
