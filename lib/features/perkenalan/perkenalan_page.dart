import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';

// shortcut: perkenalan tampil di setiap buka aplikasi; ISSUE data menyimpan pengaturan.perkenalan_selesai.
class PerkenalanPage extends StatefulWidget {
  const PerkenalanPage({super.key});

  @override
  State<PerkenalanPage> createState() => _PerkenalanPageState();
}

class _PerkenalanPageState extends State<PerkenalanPage> {
  final _halaman = PageController();
  int _ke = 0;

  static const _isi = [
    ('01-mengintip', 'Hai, aku Nuri!',
        'Aku bantu kamu jeli membaca label gizi. Foto labelnya, aku hitung gula dan natriumnya.'),
    ('09-perisai', 'Bukan saran medis',
        'Aku membantu memantau. Hasil bacaanku bisa keliru, jadi cocokkan dengan label ya.'),
  ];

  @override
  void dispose() {
    _halaman.dispose();
    super.dispose();
  }

  void _lanjut() {
    if (_ke == _isi.length - 1) {
      context.go('/beranda');
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
                  onPressed: () => context.go('/beranda'),
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
