import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../aktivitas/domain/sesi_olahraga.dart';
import '../aktivitas/presentation/aktivitas_cubit.dart';
import '../asupan/asupan_cubit.dart';
import '../pengingat/presentation/lembar_pengingat.dart';
import '../pengingat/presentation/pengingat_cubit.dart';
import '../tantangan/presentation/tantangan_cubit.dart';
import 'domain/profil_batas.dart';
import 'presentation/profil_cubit.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> with WidgetsBindingObserver {
  bool _proses = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AktivitasCubit>().muat();
    }
  }

  Future<void> _ketukAktivitas() async {
    if (_proses) return;
    final aktivitasCubit = context.read<AktivitasCubit>();
    final aktivitasState = aktivitasCubit.state;
    if (aktivitasState.terhubung) {
      await context.push('/aktivitas/izin');
      return;
    }
    if (aktivitasState.statusPerangkat == StatusHealthConnect.perluPasang) {
      await _tampilkanLembarPasangHealthConnect();
      return;
    }
    if (aktivitasState.statusPerangkat == StatusHealthConnect.tidakDidukung) {
      await _tampilkanLembarTidakDidukung();
      return;
    }

    setState(() => _proses = true);
    try {
      final ok = await aktivitasCubit.mintaIzin();
      if (!mounted) return;
      final router = GoRouter.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ok ? 'Health Connect terhubung.' : 'Izin Health Connect belum diberikan.'),
            action: ok ? null : SnackBarAction(label: 'Info', onPressed: () => router.push('/aktivitas/izin')),
          ),
        );
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _tampilkanLembarPasangHealthConnect() => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Warna.kartu,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s20, Jarak.layar, Jarak.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Health Connect belum terpasang', style: judulKecil()),
              const SizedBox(height: Jarak.s8),
              Text(
                'Untuk menampilkan jumlah langkah dan sesi olahraga, pasang aplikasi Health Connect dari Play Store. '
                'JeliLabel hanya membaca data dan tidak mengirimnya ke server.',
                style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
              ),
              const SizedBox(height: Jarak.s16),
              TombolTebal(
                label: 'Buka Play Store',
                onPressed: () async {
                  final cubit = context.read<AktivitasCubit>();
                  Navigator.pop(c);
                  await cubit.bukaPlayStore();
                },
              ),
              const SizedBox(height: Jarak.s8),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/aktivitas/izin');
                },
                child: Text('Baca penjelasan izin', style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua)),
              ),
            ],
          ),
        ),
      );

  Future<void> _tampilkanLembarTidakDidukung() => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Warna.kartu,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s20, Jarak.layar, Jarak.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Health Connect tidak tersedia', style: judulKecil()),
              const SizedBox(height: Jarak.s8),
              Text(
                'Layanan Health Connect tidak didukung di perangkat atau profil ini. '
                'Fitur catat label gizi tetap bisa digunakan seperti biasa.',
                style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
              ),
              const SizedBox(height: Jarak.s16),
              TombolTebal(
                label: 'Tutup',
                onPressed: () => Navigator.pop(c),
              ),
              const SizedBox(height: Jarak.s8),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/aktivitas/izin');
                },
                child: Text('Baca penjelasan izin', style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua)),
              ),
            ],
          ),
        ),
      );

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
      final asupanCubit = context.read<AsupanCubit>();
      final profilCubit = context.read<ProfilCubit>();
      final tantanganCubit = context.read<TantanganCubit>();
      final pengingatCubit = context.read<PengingatCubit>();
      await asupanCubit.resetSemuaData();
      profilCubit.resetKosong();
      await pengingatCubit.resetKosong();
      await tantanganCubit.muat();
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

  Future<void> _pilihProfil(int profilId) async {
    if (_proses) return;
    setState(() => _proses = true);
    try {
      await context.read<ProfilCubit>().pilihProfil(profilId);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _hapusProfil(ProfilPengguna p) async {
    final id = p.id;
    if (_proses || id == null) return;
    final setuju = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus profil ${p.nama}?', style: judulKecil()),
        content: Text(
          'Seluruh catatan konsumsi milik ${p.nama} di HP ini juga akan dihapus.',
          style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Warna.tinggiChip, foregroundColor: Warna.kartu),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (setuju != true || !mounted) return;
    setState(() => _proses = true);
    final cubit = context.read<ProfilCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await cubit.hapusProfil(id);
      if (!mounted) return;
      if (!ok) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(cubit.state.galat ?? 'Gagal menghapus profil.')));
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jumlahLencana = context.watch<TantanganCubit>().state.lencana.length;
    final aktivitasState = context.watch<AktivitasCubit>().state;
    final pengingatState = context.watch<PengingatCubit>().state;
    final profilState = context.watch<ProfilCubit>().state;
    final sumberBatas = profilState.batas.sumber.label;
    final daftarAnggota = profilState.daftarProfil.isEmpty
        ? [profilState.profil]
        : profilState.daftarProfil;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
      children: [
        Text('Profil', style: judul()),
        const SizedBox(height: Jarak.s16),
        KartuPutih(
          padding: const EdgeInsets.symmetric(vertical: Jarak.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, anggota) in daftarAnggota.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Warna.jalurBilah),
                _BarisAnggota(
                  profil: anggota,
                  aktif: daftarAnggota.length == 1 || anggota.id == profilState.profil.id,
                  bisaHapus: profilState.bisaHapusProfil && anggota.id != null,
                  terkunci: _proses,
                  onPilih: (anggota.id != null && anggota.id != profilState.profil.id)
                      ? () => _pilihProfil(anggota.id!)
                      : null,
                  onHapus: () => _hapusProfil(anggota),
                ),
              ],
              const Divider(height: 1, color: Warna.jalurBilah),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: (_proses || !profilState.bisaTambahProfil)
                      ? null
                      : () => context.push('/profil/batas?tambah=1'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: profilState.bisaTambahProfil ? Warna.hijauTua : Warna.tintaLembut,
                          ),
                          const SizedBox(width: Jarak.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tambah anggota keluarga',
                                  style: teksBadan(
                                    bobot: FontWeight.w800,
                                    warna: profilState.bisaTambahProfil ? Warna.hijauTua : Warna.tintaLembut,
                                  ),
                                ),
                                if (!profilState.bisaTambahProfil)
                                  Text(
                                    'Maksimal $maksProfilKeluarga profil tercapai',
                                    style: teksKecil(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Jarak.s12),
        KartuPutih(
          padding: const EdgeInsets.symmetric(vertical: Jarak.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarisMenu(
                label: 'Batas harian',
                ikon: Icons.tune_rounded,
                nilai: sumberBatas,
                onTap: () => context.push('/profil/batas'),
              ),
              const Divider(height: 1, color: Warna.jalurBilah),
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
              _BarisMenu(
                label: 'Tantangan dan lencana',
                ikon: Icons.emoji_events_outlined,
                nilai: '$jumlahLencana lencana',
                onTap: () => context.push('/tantangan'),
              ),
              const Divider(height: 1, color: Warna.jalurBilah),
              _BarisMenu(
                label: 'Langkah dan olahraga',
                ikon: Icons.directions_walk_rounded,
                nilai: aktivitasState.terhubung ? 'Terhubung' : 'Belum terhubung',
                onTap: (_proses || aktivitasState.memintaIzin) ? null : _ketukAktivitas,
              ),
              const Divider(height: 1, color: Warna.jalurBilah),
              _BarisMenu(
                label: 'Pengingat',
                ikon: Icons.notifications_none_rounded,
                nilai: pengingatState.aktif ? pengingatState.jamTeks : 'Mati',
                onTap: _proses ? null : () => tampilkanLembarPengingat(context),
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
}

class _BarisAnggota extends StatelessWidget {
  const _BarisAnggota({
    required this.profil,
    required this.aktif,
    required this.bisaHapus,
    required this.terkunci,
    required this.onPilih,
    required this.onHapus,
  });

  final ProfilPengguna profil;
  final bool aktif;
  final bool bisaHapus;
  final bool terkunci;
  final VoidCallback? onPilih;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) => Material(
        color: aktif ? Warna.oranyeMuda : Warna.kartu,
        child: InkWell(
          onTap: terkunci ? null : onPilih,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s8, Jarak.s8, Jarak.s8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Warna.permukaanRedup,
                      shape: BoxShape.circle,
                    ),
                    child: Text(profil.hurufAwal, style: judulKecil()),
                  ),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profil.nama,
                          style: teksBadan(bobot: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profil.keteranganSingkat,
                          style: teksLabel(warna: Warna.tintaLembut),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (aktif) ...[
                    const SizedBox(width: Jarak.s8),
                    Text('Aktif', style: teksKecil(bobot: FontWeight.w800, warna: Warna.hijauTua)),
                  ],
                  if (bisaHapus)
                    IconButton(
                      onPressed: terkunci ? null : onHapus,
                      tooltip: 'Hapus ${profil.nama}',
                      icon: const Icon(Icons.delete_outline_rounded, color: Warna.tinggiChip),
                    )
                  else
                    const SizedBox(width: Jarak.s8),
                ],
              ),
            ),
          ),
        ),
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
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
              child: Row(
                children: [
                  Icon(ikon, color: warna ?? Warna.tinta),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      label,
                      style: teksBadan(bobot: FontWeight.w700, warna: warna ?? Warna.tinta),
                    ),
                  ),
                  if (nilai != null) ...[
                    const SizedBox(width: Jarak.s8),
                    Flexible(
                      flex: 2,
                      child: Text(
                        nilai!,
                        style: teksLabel(warna: Warna.tintaLembut),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(width: Jarak.s4),
                  const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
                ],
              ),
            ),
          ),
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
