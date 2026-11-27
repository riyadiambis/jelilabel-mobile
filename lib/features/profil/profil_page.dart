import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
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
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
        children: [
          Text('Profil', style: judul()),
          const SizedBox(height: Jarak.s16),
          KartuPutih(
            padding: const EdgeInsets.symmetric(vertical: Jarak.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarisMenu(
                  label: 'Paket dan langganan',
                  ikon: Icons.workspace_premium_outlined,
                  nilai: 'Gratis',
                  onTap: () => context.push('/langganan'),
                ),
                const Divider(height: 1, color: Warna.jalurBilah),
                _BarisMenu(
                  label: 'Produk saya',
                  ikon: Icons.inventory_2_outlined,
                  onTap: () => context.push('/produk'),
                ),
                const Divider(height: 1, color: Warna.jalurBilah),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s12, Jarak.s16, Jarak.s4),
                  child: Text('Data saya', style: teksKecil(bobot: FontWeight.w800)),
                ),
                _BarisMenu(
                  label: 'Salin data',
                  ikon: Icons.copy_all_rounded,
                  onTap: _proses ? null : _salinData,
                ),
                const Divider(height: 1, color: Warna.jalurBilah),
                _BarisMenu(
                  label: 'Hapus semua data',
                  ikon: Icons.delete_forever_rounded,
                  warna: Warna.tinggiChip,
                  onTap: _proses ? null : _hapusSemuaData,
                ),
                const Divider(height: 1, color: Warna.jalurBilah),
                _BarisMenu(
                  label: 'Tentang dan privasi',
                  ikon: Icons.info_outline_rounded,
                  onTap: () => context.push('/tentang'),
                ),
              ],
            ),
          ),
        ],
      );
}

class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.label,
    required this.ikon,
    required this.onTap,
    this.nilai,
    this.warna,
  });

  final String label;
  final IconData ikon;
  final VoidCallback? onTap;
  final String? nilai;
  final Color? warna;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: ListTile(
          minTileHeight: 52,
          contentPadding: const EdgeInsets.symmetric(horizontal: Jarak.s16),
          leading: Icon(ikon, color: warna ?? Warna.tinta),
          title: Text(label, style: teksBadan(bobot: FontWeight.w700, warna: warna ?? Warna.tinta)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (nilai != null) ...[
                Text(nilai!, style: teksLabel(warna: Warna.tintaLembut)),
                const SizedBox(width: Jarak.s4),
              ],
              const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
            ],
          ),
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
