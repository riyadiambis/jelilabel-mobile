import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/di/injeksi.dart';
import '../../core/format.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../aktivitas/presentation/aktivitas_cubit.dart';
import '../asupan/asupan_cubit.dart';
import '../profil/presentation/profil_cubit.dart';
import 'rapor_cubit.dart';

class RaporPage extends StatelessWidget {
  const RaporPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<RaporCubit>()..muat(),
        child: const _IsiRapor(),
      );
}

class _IsiRapor extends StatelessWidget {
  const _IsiRapor();

  @override
  Widget build(BuildContext context) => MultiBlocListener(
        listeners: [
          BlocListener<AsupanCubit, AsupanState>(
            listenWhen: (sebelum, sesudah) =>
                sebelum.daftar != sesudah.daftar ||
                sebelum.ringkasan != sesudah.ringkasan ||
                !hariSama(sebelum.hariAktif, sesudah.hariAktif),
            listener: (context, _) => context.read<RaporCubit>().muat(),
          ),
          BlocListener<AktivitasCubit, AktivitasState>(
            listenWhen: (sebelum, sesudah) => sebelum.terhubung != sesudah.terhubung,
            listener: (context, _) => context.read<RaporCubit>().muat(),
          ),
          BlocListener<ProfilCubit, ProfilState>(
            listenWhen: (sebelum, sesudah) =>
                sebelum.batas != sesudah.batas || (sebelum.sudahMuat && sebelum.profil.id != sesudah.profil.id),
            listener: (context, _) => context.read<RaporCubit>().muat(),
          ),
        ],
        child: BlocBuilder<RaporCubit, RaporState>(
          builder: (context, state) {
            final cubit = context.read<RaporCubit>();
            final r = state.ringkasan;
            return ListView(
              padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rentangMinggu(state.awalMinggu),
                            style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut),
                          ),
                          const SizedBox(height: Jarak.s4),
                          Text(
                            state.mingguIni ? 'Rapor minggu ini' : 'Rapor mingguan',
                            style: judul(tinggi: 1.2),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: state.memuat ? null : cubit.mingguSebelumnya,
                      tooltip: 'Minggu sebelumnya',
                      icon: const Icon(Icons.chevron_left_rounded, color: Warna.tinta),
                    ),
                    IconButton(
                      onPressed: (!state.memuat && state.bisaKeMingguBerikutnya) ? cubit.mingguBerikutnya : null,
                      tooltip: 'Minggu berikutnya',
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: state.bisaKeMingguBerikutnya ? Warna.tinta : Warna.garis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Jarak.s16),
                if (state.memuat && r.jumlahCatatan == 0 && r.hariAdaCatatan == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Jarak.s32),
                    child: Center(child: CircularProgressIndicator(color: Warna.hijauTua)),
                  )
                else if (state.galat != null && r.jumlahCatatan == 0)
                  KartuPutih(
                    child: Text(state.galat!, style: teksBadan(warna: Warna.tinggiChip)),
                  )
                else if (r.jumlahCatatan == 0)
                  const _MingguKosong()
                else ...[
                  _KartuUtamaRapor(
                    hariDiBawahBatas: r.hariGulaDiBawahBatas,
                    hariTercatat: r.hariAdaCatatan,
                    hariKosong: state.hariKosong,
                    teksPerbandingan: state.teksPerbandingan,
                  ),
                  const SizedBox(height: Jarak.s12),
                  if (state.rataLangkahMinggu == null)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _PetakRata(nama: 'Gula', nilai: '${angka(r.rataGula)} g')),
                          const SizedBox(width: Jarak.s8),
                          Expanded(child: _PetakRata(nama: 'Natrium', nilai: '${angka(r.rataNatrium)} mg')),
                          const SizedBox(width: Jarak.s8),
                          Expanded(child: _PetakRata(nama: 'Lemak', nilai: '${angka(r.rataLemak)} g')),
                        ],
                      ),
                    )
                  else ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _PetakRata(nama: 'Gula', nilai: '${angka(r.rataGula)} g')),
                          const SizedBox(width: Jarak.s8),
                          Expanded(child: _PetakRata(nama: 'Natrium', nilai: '${angka(r.rataNatrium)} mg')),
                        ],
                      ),
                    ),
                    const SizedBox(height: Jarak.s8),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _PetakRata(nama: 'Lemak', nilai: '${angka(r.rataLemak)} g')),
                          const SizedBox(width: Jarak.s8),
                          Expanded(
                            child: _PetakRata(nama: 'Langkah', nilai: ribuan(state.rataLangkahMinggu!)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Jarak.s12),
                  _KartuPenyumbang(penyumbang: state.penyumbang),
                ],
              ],
            );
          },
        ),
      );
}

class _MingguKosong extends StatelessWidget {
  const _MingguKosong();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s20),
        decoration: BoxDecoration(
          color: Warna.oranyeMuda,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Maskot('01-mengintip', ukuran: 120, label: 'Nuri mengintip')),
            const SizedBox(height: Jarak.s12),
            Text(
              'Belum ada catatan minggu ini',
              style: judulKecil(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Jarak.s8),
            Text(
              'Catat asupan harianmu dari Beranda untuk melihat ringkasan minggu ini.',
              style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Jarak.s16),
            TombolTebal(
              label: 'Ke Beranda',
              onPressed: () => context.go('/beranda'),
            ),
          ],
        ),
      );
}

class _KartuUtamaRapor extends StatelessWidget {
  const _KartuUtamaRapor({
    required this.hariDiBawahBatas,
    required this.hariTercatat,
    required this.hariKosong,
    required this.teksPerbandingan,
  });

  final int hariDiBawahBatas;
  final int hariTercatat;
  final int hariKosong;
  final String teksPerbandingan;

  @override
  Widget build(BuildContext context) {
    final senang = hariDiBawahBatas >= hariTercatat - 1;
    return Container(
      padding: const EdgeInsets.all(Jarak.s16),
      decoration: BoxDecoration(
        color: Warna.oranyeMuda,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Maskot(
            senang ? '05-senang' : '01-mengintip',
            ukuran: 88,
            label: senang ? 'Nuri senang' : 'Nuri mengintip',
          ),
            const SizedBox(width: Jarak.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$hariDiBawahBatas', style: judulBesar(tinggi: 1.05)),
                      TextSpan(text: ' dari 7 hari', style: judulKecil()),
                    ]),
                  ),
                  const SizedBox(height: Jarak.s4),
                  Text(
                    'gula di bawah batas. $teksPerbandingan',
                    style: teksLabel(bobot: FontWeight.w700, tinggi: 1.4),
                  ),
                  if (hariKosong > 0) ...[
                    const SizedBox(height: Jarak.s4),
                    Text(
                      '$hariKosong hari belum ada catatan',
                      style: teksKecil(bobot: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _PetakRata extends StatelessWidget {
  const _PetakRata({required this.nama, required this.nilai});
  final String nama;
  final String nilai;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s12),
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Warna.garis),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nama, style: teksKecil(bobot: FontWeight.w800)),
            const SizedBox(height: Jarak.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(nilai, style: judulKecil()),
            ),
            const SizedBox(height: Jarak.s4),
            Text('rata-rata/hari', style: teksKecil()),
          ],
        ),
      );
}

class _KartuPenyumbang extends StatelessWidget {
  const _KartuPenyumbang({required this.penyumbang});
  final List<PenyumbangGula> penyumbang;

  @override
  Widget build(BuildContext context) => KartuPutih(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Penyumbang gula terbesar', style: teksBadan(bobot: FontWeight.w800)),
            const SizedBox(height: Jarak.s12),
            if (penyumbang.isEmpty)
              Text(
                'Belum ada produk bergula yang dicatat minggu ini.',
                style: teksLabel(warna: Warna.tintaLembut),
              )
            else
              for (final (i, item) in penyumbang.indexed) ...[
                if (i > 0) const SizedBox(height: Jarak.s12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.nama,
                        style: teksLabel(bobot: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Jarak.s8),
                    Text(
                      '${(item.persen * 100).round()}% · ${item.jumlahKali} kali',
                      style: teksLabel(warna: Warna.tintaLembut),
                    ),
                  ],
                ),
                const SizedBox(height: Jarak.s4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.persen.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: Warna.tinta,
                    backgroundColor: Warna.jalurBilah,
                  ),
                ),
              ],
          ],
        ),
      );
}
