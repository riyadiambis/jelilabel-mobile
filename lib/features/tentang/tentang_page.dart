import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../profil/presentation/profil_cubit.dart';

class TentangPage extends StatelessWidget {
  const TentangPage({super.key});

  static const _teksDisclaimerLengkap =
      'Aplikasi ini mencatat asupan gula, natrium, dan lemak harian dan membandingkannya dengan batas Kemenkes '
      '(4 sendok makan gula, 1 sendok teh garam, 5 sendok makan minyak per hari). JeliLabel bukan alat diagnosis, '
      'bukan pengganti dokter atau ahli gizi, dan tidak memberi saran obat. Hasil baca AI bisa keliru — selalu cocokkan '
      'dengan label kemasan. Batas harian mengacu pesan Kemenkes G4 G1 L5 (Permenkes 30/2013).';

  void _bukaDisclaimer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Warna.kartu,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Maskot('09-perisai', ukuran: 48),
              const SizedBox(width: Jarak.s12),
              Expanded(child: Text('Bukan saran medis', style: judulKecil())),
              IconButton(
                onPressed: () => Navigator.pop(c),
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
              ),
            ]),
            const SizedBox(height: Jarak.s12),
            Text(_teksDisclaimerLengkap, style: teksLabel(tinggi: 1.55)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batas = context.watch<ProfilCubit>().state.batas;
    void segera() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Segera hadir')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang dan privasi'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profil');
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
            const Maskot('01-mengintip', ukuran: 140, label: 'Nuri, maskot JeliLabel'),
            const SizedBox(height: Jarak.s8),
            Center(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Jeli', style: judul()),
                TextSpan(text: 'Label', style: judul(warna: Warna.hijauTua)),
              ])),
            ),
            Center(child: Text('Versi 1.0.0 · Ofi Labs', style: teksKecil())),
            const SizedBox(height: Jarak.s16),
            KartuPutih(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Acuan batas harian', style: judulKecil()),
                const SizedBox(height: Jarak.s8),
                Text(
                  'Kemenkes RI (Permenkes No. 30 Tahun 2013): gula 50 g, natrium 2000 mg, dan lemak 67 g per hari untuk orang dewasa.',
                  style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.5),
                ),
                if (batas.berbedaDariKemenkes) ...[
                  const SizedBox(height: Jarak.s12),
                  const Divider(height: 1, color: Warna.jalurBilah),
                  const SizedBox(height: Jarak.s12),
                  Text(
                    'Batas harian aktif (${batas.sumber.label})',
                    style: teksLabel(bobot: FontWeight.w800),
                  ),
                  const SizedBox(height: Jarak.s8),
                  _BarisAcuanTentang(
                    nama: 'Gula',
                    nilai: '${angka(batas.gulaG)} g',
                    acuan: batas.gulaBerbedaDariKemenkes ? 'Acuan Kemenkes: ${angka(batasGulaHarianG)} g' : null,
                  ),
                  const SizedBox(height: Jarak.s4),
                  _BarisAcuanTentang(
                    nama: 'Natrium',
                    nilai: '${angka(batas.natriumMg)} mg',
                    acuan: batas.natriumBerbedaDariKemenkes ? 'Acuan Kemenkes: ${angka(batasNatriumHarianMg)} mg' : null,
                  ),
                  const SizedBox(height: Jarak.s4),
                  _BarisAcuanTentang(
                    nama: 'Lemak',
                    nilai: '${angka(batas.lemakG)} g',
                    acuan: batas.lemakBerbedaDariKemenkes ? 'Acuan Kemenkes: ${angka(batasLemakHarianG)} g' : null,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: Jarak.s12),
            KartuPutih(
              padding: const EdgeInsets.fromLTRB(Jarak.s8, Jarak.s12, Jarak.s16, Jarak.s4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Maskot('09-perisai', ukuran: 72),
                const SizedBox(width: Jarak.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bukan saran medis', style: judulKecil()),
                    const SizedBox(height: Jarak.s8),
                    for (final butir in const [
                      'Alat bantu catat, bukan diagnosis atau pengganti dokter.',
                      'Hasil baca AI bisa keliru — selalu cocokkan dengan label kemasan.',
                      'Acuan batas harian: Kemenkes G4 G1 L5 (Permenkes 30/2013).',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: Jarak.s4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('• ', style: teksLabel(bobot: FontWeight.w700)),
                          Expanded(child: Text(butir, style: teksLabel(tinggi: 1.45))),
                        ]),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _bukaDisclaimer(context),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                        ),
                        child: Text(
                          'Baca selengkapnya',
                          style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: Jarak.s12),
            KartuPutih(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
              child: Column(children: [
                _Tautan('Kebijakan privasi', segera),
                const Divider(height: 1, color: Warna.jalurBilah),
                _Tautan('Hubungi Ofi Labs', segera),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tautan extends StatelessWidget {
  const _Tautan(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: ListTile(
          minTileHeight: 52,
          title: Text(label, style: teksBadan(bobot: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
          onTap: onTap,
        ),
      );
}

class _BarisAcuanTentang extends StatelessWidget {
  const _BarisAcuanTentang({
    required this.nama,
    required this.nilai,
    this.acuan,
  });

  final String nama;
  final String nilai;
  final String? acuan;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: Jarak.s8,
        runSpacing: Jarak.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$nama: $nilai', style: teksLabel(bobot: FontWeight.w700)),
          if (acuan != null) Text(acuan!, style: teksKecil()),
        ],
      );
}
