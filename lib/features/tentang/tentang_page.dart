import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

class TentangPage extends StatefulWidget {
  const TentangPage({super.key});

  @override
  State<TentangPage> createState() => _TentangPageState();
}

class _TentangPageState extends State<TentangPage> {
  bool _proses = false;

  Future<void> _salinData() async {
    if (_proses) return;
    setState(() => _proses = true);
    try {
      final cubit = context.read<AsupanCubit>();
      final json = await cubit.eksporDataJson();
      final csv = await cubit.eksporDataCsv();
      final jumlah = await cubit.jumlahCatatan();
      if (!mounted) return;
      final tersalin = await showDialog<bool>(
        context: context,
        builder: (_) => _DialogPratinjauData(json: json, csv: csv),
      );
      if (tersalin == true && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Data disalin ($jumlah catatan). Tempel di aplikasi catatan atau dokumen.')),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Gagal menyalin data. Coba lagi.')));
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _hapusSemuaData() async {
    if (_proses) return;
    final setuju = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogHapusSemua(),
    );
    if (setuju != true || !mounted) return;
    setState(() => _proses = true);
    try {
      await context.read<AsupanCubit>().resetSemuaData();
      if (!mounted) return;
      context.go('/perkenalan');
    } catch (_) {
      if (!mounted) return;
      setState(() => _proses = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal menghapus data. Coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    void segera() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Segera hadir')));

    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
      const Maskot('01-mengintip', ukuran: 140, label: 'Nuri, maskot JeliLabel'),
      Center(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Jeli', style: fredoka(26)),
          TextSpan(text: 'Label', style: fredoka(26, warna: Warna.hijauTua)),
        ])),
      ),
      Center(child: Text('Versi 1.0.0 · Ofi Labs', style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut))),
      const SizedBox(height: 16),
      KartuPutih(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Acuan batas harian', style: fredoka(17)),
          const SizedBox(height: 6),
          Text(
            'Kemenkes RI (Permenkes No. 30 Tahun 2013): gula 50 g dan natrium 2000 mg per hari untuk orang dewasa.',
            style: nunito(14, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.5),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      KartuPutih(
        padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Maskot('09-perisai', ukuran: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bukan saran medis', style: fredoka(17)),
              const SizedBox(height: 4),
              Text(
                'JeliLabel membantu memantau, bukan saran medis. Aplikasi ini mencatat asupan gula dan natrium harian dan membandingkannya dengan batas Kemenkes (4 sendok makan gula, 1 sendok teh garam per hari). JeliLabel bukan alat diagnosis, bukan pengganti dokter atau ahli gizi, dan tidak memberi saran obat. Hasil baca AI bisa keliru — selalu cocokkan dengan label kemasan. Batas harian mengacu pesan Kemenkes G4 G1 L5 (Permenkes 30/2013).',
                style: nunito(13, FontWeight.w400, tinggi: 1.45),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      KartuPutih(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Data saya', style: fredoka(17)),
          const SizedBox(height: 4),
          _Tautan(
            'Salin data',
            _proses ? null : _salinData,
            ikon: Icons.copy_all_rounded,
          ),
          const Divider(height: 1, color: Warna.jalurBilah),
          _Tautan(
            'Hapus semua data',
            _proses ? null : _hapusSemuaData,
            ikon: Icons.delete_forever_rounded,
            warna: Warna.tinggiChip,
          ),
        ]),
      ),
      const SizedBox(height: 14),
      KartuPutih(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          _Tautan('Paket dan langganan', () => context.push('/langganan')),
          const Divider(height: 1, color: Warna.jalurBilah),
          _Tautan('Kebijakan privasi', segera),
          const Divider(height: 1, color: Warna.jalurBilah),
          _Tautan('Hubungi Ofi Labs', segera),
        ]),
      ),
    ]);
  }
}

class _Tautan extends StatelessWidget {
  const _Tautan(this.label, this.onTap, {this.ikon, this.warna});
  final String label;
  final VoidCallback? onTap;
  final IconData? ikon;
  final Color? warna;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: ListTile(
          minTileHeight: 52,
          leading: ikon == null ? null : Icon(ikon, color: warna ?? Warna.hijauTua),
          title: Text(label, style: nunito(15, FontWeight.w700, warna: warna ?? Warna.tinta)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
          onTap: onTap,
        ),
      );
}

class _DialogPratinjauData extends StatefulWidget {
  const _DialogPratinjauData({required this.json, required this.csv});
  final String json;
  final String csv;

  @override
  State<_DialogPratinjauData> createState() => _DialogPratinjauDataState();
}

class _DialogPratinjauDataState extends State<_DialogPratinjauData> {
  bool _formatJson = true;

  @override
  Widget build(BuildContext context) {
    final isi = _formatJson ? widget.json : widget.csv;
    return AlertDialog(
      title: Text('Salin data', style: fredoka(20)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('JSON')),
                ButtonSegment(value: false, label: Text('CSV')),
              ],
              selected: {_formatJson},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _formatJson = s.first),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Warna.latar,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Warna.garis),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(isi, style: nunito(12, FontWeight.w400, tinggi: 1.4)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: isi));
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Salin'),
        ),
      ],
    );
  }
}

class _DialogHapusSemua extends StatefulWidget {
  const _DialogHapusSemua();

  @override
  State<_DialogHapusSemua> createState() => _DialogHapusSemuaState();
}

class _DialogHapusSemuaState extends State<_DialogHapusSemua> {
  final _c = TextEditingController();

  bool get _cocok => _c.text.trim() == 'HAPUS';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Hapus semua data?', style: fredoka(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seluruh catatan, produk, dan pengaturan di HP ini akan dihapus. Tindakan ini tidak bisa dibatalkan.',
                style: nunito(14, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.45),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Ketik HAPUS'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Warna.tinggiChip, foregroundColor: Colors.white),
            onPressed: _cocok ? () => Navigator.pop(context, true) : null,
            child: const Text('Hapus'),
          ),
        ],
      );
}
