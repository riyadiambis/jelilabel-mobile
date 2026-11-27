import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/di/injeksi.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';
import '../bagikan/data_kartu_bagikan.dart';
import '../bagikan/kartu_bagikan.dart';
import 'produk_cubit.dart';

class ProdukSayaPage extends StatelessWidget {
  const ProdukSayaPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<ProdukCubit>()..muat(),
        child: const _IsiProdukSaya(),
      );
}

class _IsiProdukSaya extends StatefulWidget {
  const _IsiProdukSaya();

  @override
  State<_IsiProdukSaya> createState() => _IsiProdukSayaState();
}

class _IsiProdukSayaState extends State<_IsiProdukSaya> {
  final _cari = TextEditingController();
  bool _proses = false;

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _catat(ProdukRingkas produk) async {
    if (_proses) return;
    final porsi = await tampilkanDialogPorsi(
      context,
      judulDialog: 'Catat ${produk.nama}',
      porsiAwal: 1,
      labelSimpan: 'Catat',
    );
    if (porsi == null || !mounted) return;
    setState(() => _proses = true);
    final asupanCubit = context.read<AsupanCubit>();
    final produkCubit = context.read<ProdukCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await asupanCubit.catatProduk(produk.id, porsi);
    if (!mounted) return;
    if (ok) {
      await produkCubit.muat();
      if (!mounted) return;
    }
    setState(() => _proses = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? '${produk.nama} dicatat untuk hari ini' : 'Gagal mencatat produk.'),
        ),
      );
  }

  Future<void> _bagikan(ProdukRingkas produk) async {
    if (_proses) return;
    setState(() => _proses = true);
    try {
      await tampilkanLembarBagikan(context, DataKartuBagikan.dariProduk(produk));
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Produk saya'),
          leading: IconButton(
            onPressed: () => context.pop(),
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: BlocListener<AsupanCubit, AsupanState>(
            listenWhen: (sebelum, sesudah) => sebelum.daftar != sesudah.daftar,
            listener: (context, _) => context.read<ProdukCubit>().muat(),
            child: BlocBuilder<ProdukCubit, ProdukState>(
              builder: (context, state) {
                final cubit = context.read<ProdukCubit>();
                final daftar = state.tampil;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s8, Jarak.layar, Jarak.s24),
                  children: [
                    TextField(
                      controller: _cari,
                      onChanged: cubit.ubahKueri,
                      style: teksBadan(),
                      decoration: InputDecoration(
                        hintText: 'Cari produk',
                        hintStyle: teksBadan(warna: Warna.tidakDiketahui),
                        prefixIcon: const Icon(Icons.search_rounded, color: Warna.tintaLembut),
                        suffixIcon: _cari.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _cari.clear();
                                  cubit.ubahKueri('');
                                },
                                tooltip: 'Hapus pencarian',
                                icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
                              ),
                      ),
                    ),
                    const SizedBox(height: Jarak.s12),
                    Wrap(
                      spacing: Jarak.s8,
                      runSpacing: Jarak.s8,
                      children: [
                        _PilUrutan(
                          label: 'Sering',
                          terpilih: state.urutan == UrutanProduk.sering,
                          onTap: () => cubit.pilihUrutan(UrutanProduk.sering),
                        ),
                        _PilUrutan(
                          label: 'Terbaru',
                          terpilih: state.urutan == UrutanProduk.terbaru,
                          onTap: () => cubit.pilihUrutan(UrutanProduk.terbaru),
                        ),
                      ],
                    ),
                    const SizedBox(height: Jarak.s16),
                    if (state.memuat && state.semua.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Jarak.s32),
                        child: Center(child: CircularProgressIndicator(color: Warna.hijauTua)),
                      )
                    else if (state.galat != null && state.semua.isEmpty)
                      KartuPutih(
                        child: Text(state.galat!, style: teksBadan(warna: Warna.tinggiChip)),
                      )
                    else if (state.semua.isEmpty)
                      const _KosongProduk()
                    else if (daftar.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Jarak.s24),
                        child: Text(
                          'Produk "${state.kueri.trim()}" tidak ditemukan.',
                          style: teksBadan(warna: Warna.tintaLembut),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final (i, p) in daftar.indexed) ...[
                        if (i > 0) const SizedBox(height: Jarak.s12),
                        _BarisProduk(
                          produk: p,
                          terkunci: _proses,
                          onCatat: () => _catat(p),
                          onBagikan: () => _bagikan(p),
                        ),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      );
}

class _PilUrutan extends StatelessWidget {
  const _PilUrutan({
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: terpilih,
        child: Material(
          color: terpilih ? Warna.oranyeLembut : Warna.kartu,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: terpilih ? Warna.oranye : Warna.garis, width: terpilih ? 2 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (terpilih) ...[
                      const Icon(Icons.check_rounded, size: 16, color: Warna.tinta),
                      const SizedBox(width: Jarak.s4),
                    ],
                    Text(label, style: teksLabel(bobot: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _BarisProduk extends StatelessWidget {
  const _BarisProduk({
    required this.produk,
    required this.terkunci,
    required this.onCatat,
    required this.onBagikan,
  });

  final ProdukRingkas produk;
  final bool terkunci;
  final VoidCallback onCatat;
  final VoidCallback onBagikan;

  static String _nilai(double? v) => v == null ? '-' : angka(v);

  @override
  Widget build(BuildContext context) {
    final isiGizi =
        '${_nilai(produk.gulaG)} g gula · ${_nilai(produk.natriumMg)} mg natrium · ${_nilai(produk.lemakTotalG)} g lemak';
    return KartuPutih(
      padding: const EdgeInsets.fromLTRB(Jarak.s12, Jarak.s12, Jarak.s8, Jarak.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produk.nama,
                  style: teksBadan(bobot: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Jarak.s4),
                Text(
                  '$isiGizi · ${produk.jumlahKali} kali',
                  style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: Jarak.s4),
          IconButton(
            onPressed: terkunci ? null : onBagikan,
            tooltip: 'Bagikan ${produk.nama}',
            icon: Icon(Icons.share_outlined, color: terkunci ? Warna.tintaLembut : Warna.tinta),
          ),
          const SizedBox(width: Jarak.s4),
          Semantics(
            button: true,
            enabled: !terkunci,
            label: 'Catat ${produk.nama}',
            child: Material(
              color: terkunci ? Warna.jalurBilah : Warna.hijauTua,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: terkunci ? null : onCatat,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: terkunci ? Warna.garis : Warna.hijauTepi,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: terkunci ? Warna.tintaLembut : Warna.kartu,
                      ),
                      const SizedBox(width: Jarak.s4),
                      Text(
                        'Catat',
                        style: teksLabel(
                          bobot: FontWeight.w800,
                          warna: terkunci ? Warna.tintaLembut : Warna.kartu,
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
    );
  }
}

class _KosongProduk extends StatelessWidget {
  const _KosongProduk();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Jarak.s24),
        child: Column(
          children: [
            const Maskot('01-mengintip', ukuran: 120, label: 'Nuri mengintip'),
            const SizedBox(height: Jarak.s12),
            Text(
              'Produk yang kamu catat muncul di sini',
              style: teksBadan(bobot: FontWeight.w700, warna: Warna.tintaLembut),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
