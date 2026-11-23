import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

class PerkenalanPage extends StatefulWidget {
  const PerkenalanPage({super.key});

  @override
  State<PerkenalanPage> createState() => _PerkenalanPageState();
}

class _PerkenalanPageState extends State<PerkenalanPage> {
  final _halaman = PageController();
  int _ke = 0;

  static const _isi = [
    (
      '01-mengintip',
      'Nuri mengintip',
      'Hai, aku Nuri!',
      'Foto label gizi kemasan. Aku bacakan gula dan natriumnya dalam hitungan detik.',
    ),
    (
      '05-senang',
      'Nuri senang',
      'Lihat jatah harianmu',
      'Setiap catatan mengurangi jatah gula 50 g dan natrium 2.000 mg per hari dari Kemenkes.',
    ),
    (
      '09-perisai',
      'Nuri dengan perisai',
      'Bukan saran medis',
      'JeliLabel membantu memantau, bukan menggantikan dokter. Hasil baca AI bisa keliru, jadi cocokkan dengan label.',
    ),
  ];

  @override
  void dispose() {
    _halaman.dispose();
    super.dispose();
  }

  Future<void> _selesai() async {
    try {
      await context.read<AsupanCubit>().selesaikanPerkenalan();
    } catch (_) {}
    if (mounted) context.go('/beranda');
  }

  void _lanjut() {
    if (_ke == _isi.length - 1) {
      _selesai();
    } else {
      _halaman.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bukanAkhir = _ke < _isi.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s8),
              child: Align(
                alignment: Alignment.centerRight,
                child: bukanAkhir
                    ? TextButton(
                        onPressed: _selesai,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: Jarak.s12),
                        ),
                        child: Text('Lewati', style: teksBadan(bobot: FontWeight.w800, warna: Warna.tintaLembut)),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _halaman,
              itemCount: _isi.length,
              onPageChanged: (i) => setState(() => _ke = i),
              itemBuilder: (_, i) {
                final (pose, labelMaskot, judulHalaman, teks) = _isi[i];
                return LayoutBuilder(
                  builder: (_, c) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Jarak.s32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Maskot(pose, ukuran: 160, label: labelMaskot),
                            const SizedBox(height: Jarak.s24),
                            Text(judulHalaman, style: judulBesar(tinggi: 1.15), textAlign: TextAlign.center),
                            const SizedBox(height: Jarak.s16),
                            Text(
                              teks,
                              style: teksBadan(warna: Warna.tintaLembut, tinggi: 1.55),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
            child: Column(children: [
              Semantics(
                label: 'Halaman ${_ke + 1} dari ${_isi.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _isi.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                        width: i == _ke ? Jarak.s24 : Jarak.s8,
                        height: Jarak.s8,
                        decoration: BoxDecoration(
                          color: i == _ke ? Warna.hijauTua : Warna.garis,
                          borderRadius: BorderRadius.circular(Jarak.s4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Jarak.s24),
              SizedBox(
                width: double.infinity,
                child: TombolTebal(
                  label: bukanAkhir ? 'Lanjut' : 'Mulai pakai JeliLabel',
                  onPressed: _lanjut,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
