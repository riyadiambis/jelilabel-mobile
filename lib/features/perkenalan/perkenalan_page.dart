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
    ('03-memegang-hp', 'Hai, aku Nuri!',
        'Pindai label gizi kemasan, langsung tahu gula dan natriumnya.'),
    ('05-senang', 'Catat, lihat jatah harian',
        'Catat yang kamu makan, lalu lihat sisa jatah gula dan garam harianmu menurut Kemenkes.'),
    ('09-perisai', 'Bukan saran medis',
        'Aku membantu memantau, bukan menggantikan dokter. Hasil baca AI bisa keliru, jadi selalu cocokkan dengan label kemasan.'),
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
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _selesai,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text('Lewati', style: nunito(15, FontWeight.w700, warna: Warna.tintaLembut)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _halaman,
                  itemCount: _isi.length,
                  onPageChanged: (i) => setState(() => _ke = i),
                  itemBuilder: (_, i) {
                    final (pose, judul, teks) = _isi[i];
                    return SingleChildScrollView(
                      child: Column(children: [
                        const SizedBox(height: 24),
                        Maskot(pose, ukuran: 220, label: 'Nuri, maskot JeliLabel'),
                        const SizedBox(height: 16),
                        Text(judul, style: fredoka(30), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(teks,
                            style: nunito(16, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.55),
                            textAlign: TextAlign.center),
                      ]),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _isi.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _ke ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _ke ? Warna.hijauTua : Warna.garis,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TombolTebal(label: _ke == _isi.length - 1 ? 'Mulai' : 'Lanjut', onPressed: _lanjut),
              ),
            ]),
          ),
        ),
      );
}
