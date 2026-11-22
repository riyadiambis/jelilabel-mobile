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

  static const _teksDisclaimerLengkap =
      'Aplikasi ini mencatat asupan gula, natrium, dan lemak harian dan membandingkannya dengan batas Kemenkes '
      '(4 sendok makan gula, 1 sendok teh garam, 5 sendok makan minyak per hari). JeliLabel bukan alat diagnosis, '
      'bukan pengganti dokter atau ahli gizi, dan tidak memberi saran obat. Hasil baca AI bisa keliru — selalu cocokkan '
      'dengan label kemasan. Batas harian mengacu pesan Kemenkes G4 G1 L5 (Permenkes 30/2013).';

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

  void _bukaDisclaimer() {
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
    void segera() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Segera hadir')));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.layar, Jarak.layar, Jarak.s24),
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
                    onPressed: _bukaDisclaimer,
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
          padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s12, Jarak.s4, Jarak.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Data saya', style: judulKecil()),
            const SizedBox(height: Jarak.s4),
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
        const SizedBox(height: Jarak.s12),
        KartuPutih(
          padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
          child: Column(children: [
            _Tautan('Paket dan langganan', () => context.push('/langganan')),
            const Divider(height: 1, color: Warna.jalurBilah),
            _Tautan('Kebijakan privasi', segera),
            const Divider(height: 1, color: Warna.jalurBilah),
            _Tautan('Hubungi Ofi Labs', segera),
          ]),
        ),
      ],
    );
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
          title: Text(label, style: teksBadan(bobot: FontWeight.w700, warna: warna ?? Warna.tinta)),
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
      title: Text('Salin data', style: judulKecil()),
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
            const SizedBox(height: Jarak.s12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Container(
                padding: const EdgeInsets.all(Jarak.s12),
                decoration: BoxDecoration(
                  color: Warna.latar,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Warna.garis),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(isi, style: teksKecil(warna: Warna.tinta, tinggi: 1.4)),
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
        title: Text('Hapus semua data?', style: judulKecil()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seluruh catatan, produk, dan pengaturan di HP ini akan dihapus. Tindakan ini tidak bisa dibatalkan.',
                style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
              ),
              const SizedBox(height: Jarak.s12),
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
            style: FilledButton.styleFrom(backgroundColor: Warna.tinggiChip, foregroundColor: Warna.kartu),
            onPressed: _cocok ? () => Navigator.pop(context, true) : null,
            child: const Text('Hapus'),
          ),
        ],
      );
}
