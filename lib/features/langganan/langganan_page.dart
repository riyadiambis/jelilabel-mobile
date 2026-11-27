import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injeksi.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';
import 'domain/layanan_langganan.dart';
import 'presentation/langganan_cubit.dart';

/// Layar JeliLabel Plus (ISSUE-23): harga dari Google Play, beli, pulihkan. Max Family belum dijual.
class LanggananPage extends StatelessWidget {
  const LanggananPage({super.key, this.cubit});

  /// Hanya untuk tes; bawaannya dibuat lewat get_it.
  final LanggananCubit? cubit;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => (cubit ?? getIt<LanggananCubit>())..muat(),
        child: const _IsiLangganan(),
      );
}

class _IsiLangganan extends StatelessWidget {
  const _IsiLangganan();

  @override
  Widget build(BuildContext context) => BlocConsumer<LanggananCubit, LanggananState>(
        listenWhen: (a, b) => b.pesan != null && a.pesan != b.pesan,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.pesan!)));
          context.read<LanggananCubit>().pesanDibaca();
        },
        builder: (context, state) {
          final cubit = context.read<LanggananCubit>();
          return Scaffold(
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Kepala(plus: state.plus),
                      const SizedBox(height: Jarak.s16),
                      _KartuPlus(state: state, onPilih: cubit.pilih),
                      const SizedBox(height: Jarak.s16),
                      const _KartuGratis(),
                      const SizedBox(height: Jarak.s16),
                      const _KartuMaxFamily(),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (state.tersedia && !state.plus) ...[
                      TombolTebal(
                        label: 'Langganan',
                        memuat: state.proses,
                        onPressed: state.proses ? null : cubit.beli,
                      ),
                      const SizedBox(height: Jarak.s8),
                    ],
                    if (state.tersedia)
                      TextButton(
                        onPressed: state.proses ? null : cubit.pulihkan,
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        child: Text(
                          'Pulihkan pembelian',
                          style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua),
                        ),
                      ),
                    TombolTebal.sekunder(
                      label: 'Kembali',
                      onPressed: state.proses ? null : () => context.pop(),
                    ),
                    const SizedBox(height: Jarak.s8),
                    Text(
                      'Tagihan lewat Google Play. Batalkan kapan saja di Play Store.',
                      style: teksKecil(),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

class _Kepala extends StatelessWidget {
  const _Kepala({required this.plus});

  final bool plus;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Maskot('05-senang', ukuran: 80, label: 'Nuri senang'),
        const SizedBox(width: Jarak.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (plus) ...[
              const _Lencana('Plus aktif'),
              const SizedBox(height: Jarak.s8),
            ],
            Text('JeliLabel Plus', style: judul(tinggi: 1.15)),
            const SizedBox(height: Jarak.s4),
            Text(
              'Pindai lebih banyak, tanpa iklan. Semua fitur lain tetap gratis.',
              style: teksLabel(warna: Warna.tintaLembut),
            ),
          ]),
        ),
      ]);
}

class _Lencana extends StatelessWidget {
  const _Lencana(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s4),
        decoration: BoxDecoration(color: Warna.oranyeLembut, borderRadius: BorderRadius.circular(999)),
        child: Text(teks, style: teksKecil(bobot: FontWeight.w800, warna: Warna.oranyeTeks)),
      );
}

class _KartuPlus extends StatelessWidget {
  const _KartuPlus({required this.state, required this.onPilih});

  final LanggananState state;
  final ValueChanged<BasePlan> onPilih;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s16),
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Warna.hijauTua, width: 2),
          boxShadow: const [BoxShadow(color: Warna.hijauTua, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Plus', style: judulKecil()),
          const SizedBox(height: Jarak.s12),
          for (final fitur in const [
            '${AsupanState.kuotaPlusMingguan} pindai per minggu',
            'Tanpa video iklan',
            'Cadangan otomatis ke awan (segera)',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Jarak.s8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_rounded, size: 18, color: Warna.hijauTua),
                const SizedBox(width: Jarak.s8),
                Expanded(child: Text(fitur, style: teksBadan())),
              ]),
            ),
          const SizedBox(height: Jarak.s4),
          if (state.memuat)
            const Center(child: CircularProgressIndicator())
          else if (!state.tersedia)
            Text('Langganan belum tersedia', style: teksBadan(bobot: FontWeight.w800))
          else if (!state.plus)
            for (final p in state.paket)
              _PilihanHarga(
                paket: p,
                terpilih: p.basePlan == state.pilihan,
                onTap: state.proses ? null : () => onPilih(p.basePlan),
              ),
        ]),
      );
}

class _PilihanHarga extends StatelessWidget {
  const _PilihanHarga({required this.paket, required this.terpilih, required this.onTap});

  final PaketPlus paket;
  final bool terpilih;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Jarak.s8),
        child: Semantics(
          button: true,
          selected: terpilih,
          child: Material(
            color: terpilih ? Warna.permukaanRedup : Warna.kartu,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: terpilih ? Warna.hijauTua : Warna.garis, width: terpilih ? 2 : 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
                  child: Row(children: [
                    Icon(
                      terpilih ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: terpilih ? Warna.hijauTua : Warna.tintaLembut,
                    ),
                    const SizedBox(width: Jarak.s12),
                    Expanded(child: Text(paket.basePlan.periode, style: teksBadan(bobot: FontWeight.w800))),
                    Text(paket.harga, style: teksBadan(bobot: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _KartuGratis extends StatelessWidget {
  const _KartuGratis();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s16),
        decoration: BoxDecoration(color: Warna.permukaanRedup, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gratis, paketmu sekarang', style: teksBadan(bobot: FontWeight.w800)),
          const SizedBox(height: Jarak.s8),
          Text(
            '${AsupanState.kuotaGratisMingguan} pindai per minggu, tambah sampai ${AsupanState.kuotaIklanMingguanMaks} lewat video. Isi manual tanpa batas, semua fitur pantau, riwayat 7/30/90 hari.',
            style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.5),
          ),
        ]),
      );
}

class _KartuMaxFamily extends StatelessWidget {
  const _KartuMaxFamily();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s16),
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Warna.garis, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: Jarak.s8, runSpacing: Jarak.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Max Family', style: judulKecil()),
            const _Lencana('Segera hadir'),
          ]),
          const SizedBox(height: Jarak.s8),
          Text(
            'Undang anggota keluarga dan berbagi kuota pindai di beberapa HP.',
            style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.5),
          ),
        ]),
      );
}
