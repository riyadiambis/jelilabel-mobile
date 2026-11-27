import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tema.dart';
import '../../../core/theme/warna.dart';
import '../../../core/widgets/komponen.dart';
import '../domain/sesi_olahraga.dart';
import 'aktivitas_cubit.dart';

/// Layar penjelasan izin Health Connect (dibuka dari intent rationale dan dari Profil).
class IzinAktivitasPage extends StatefulWidget {
  const IzinAktivitasPage({super.key});

  @override
  State<IzinAktivitasPage> createState() => _IzinAktivitasPageState();
}

class _IzinAktivitasPageState extends State<IzinAktivitasPage> {
  bool _proses = false;

  Future<void> _hubungkan() async {
    if (_proses) return;
    setState(() => _proses = true);
    final cubit = context.read<AktivitasCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await cubit.mintaIzin();
    if (!mounted) return;
    setState(() => _proses = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Health Connect terhubung.' : 'Izin Health Connect belum diberikan.',
          ),
        ),
      );
  }

  Future<void> _bukaPlayStore() async {
    if (_proses) return;
    setState(() => _proses = true);
    try {
      await context.read<AktivitasCubit>().bukaPlayStore();
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AktivitasCubit>().state;
    final terkunci = _proses || state.memintaIzin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Langkah dan olahraga'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/beranda');
            }
          },
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s12, Jarak.layar, Jarak.s24),
          children: [
            Container(
              padding: const EdgeInsets.all(Jarak.s16),
              decoration: BoxDecoration(
                color: Warna.oranyeMuda,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Maskot('09-perisai', ukuran: 72, label: 'Nuri menjaga privasi'),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Akses Health Connect', style: judulKecil(tinggi: 1.2)),
                        const SizedBox(height: Jarak.s4),
                        Text(
                          'JeliLabel hanya membaca data aktivitasmu untuk ditampilkan di HP ini.',
                          style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Jarak.s16),
            KartuPutih(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yang dibaca dari Health Connect', style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s12),
                  const _ButirData(
                    ikon: Icons.directions_walk_rounded,
                    judul: 'Jumlah langkah',
                    keterangan: 'Menampilkan langkah hari ini di Beranda dan rata-rata mingguan di Rapor.',
                  ),
                  const SizedBox(height: Jarak.s12),
                  const _ButirData(
                    ikon: Icons.directions_run_rounded,
                    judul: 'Sesi olahraga',
                    keterangan: 'Menampilkan jenis dan durasi sesi olahragamu di daftar Riwayat.',
                  ),
                  const SizedBox(height: Jarak.s12),
                  const _ButirData(
                    ikon: Icons.straighten_rounded,
                    judul: 'Jarak',
                    keterangan: 'Menampilkan jarak sesi olahraga bila tersedia di Health Connect.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Jarak.s12),
            KartuPutih(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dibaca saja dan tetap di HP', style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s8),
                  for (final butir in const [
                    'JeliLabel hanya membaca data dan tidak menulis atau mengubah catatan di Health Connect.',
                    'Data langkah dan olahraga tidak disimpan ke basis data dan tidak dikirim ke server mana pun.',
                    'Fitur ini opsional: semua fitur catat label gizi tetap berjalan penuh tanpa Health Connect.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: Jarak.s4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: teksLabel(bobot: FontWeight.w700)),
                          Expanded(
                            child: Text(butir, style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Jarak.s12),
            KartuPutih(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cara mencabut izin', style: teksBadan(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s8),
                  Text(
                    'Kamu bisa mencabut izin kapan saja lewat Setelan HP atau aplikasi Health Connect → Izin aplikasi → JeliLabel.',
                    style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Jarak.s20),
            if (state.terhubung)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
                decoration: BoxDecoration(
                  color: Warna.permukaanRedup,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Warna.garis),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 20, color: Warna.tinta),
                    const SizedBox(width: Jarak.s8),
                    Text('Status: Terhubung', style: teksLabel(bobot: FontWeight.w800)),
                  ],
                ),
              )
            else if (state.statusPerangkat == StatusHealthConnect.perluPasang)
              TombolTebal(
                label: 'Buka Play Store',
                memuat: terkunci,
                onPressed: terkunci ? null : _bukaPlayStore,
              )
            else if (state.statusPerangkat == StatusHealthConnect.tersedia)
              TombolTebal(
                label: 'Hubungkan Health Connect',
                memuat: terkunci,
                onPressed: terkunci ? null : _hubungkan,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
                decoration: BoxDecoration(
                  color: Warna.permukaanRedup,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Warna.garis),
                ),
                child: Text(
                  'Health Connect tidak tersedia di perangkat ini.',
                  style: teksLabel(warna: Warna.tintaLembut),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ButirData extends StatelessWidget {
  const _ButirData({
    required this.ikon,
    required this.judul,
    required this.keterangan,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Warna.permukaanRedup,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, size: 20, color: Warna.tinta),
          ),
          const SizedBox(width: Jarak.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: teksLabel(bobot: FontWeight.w800)),
                const SizedBox(height: Jarak.s4),
                Text(keterangan, style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.4)),
              ],
            ),
          ),
        ],
      );
}
