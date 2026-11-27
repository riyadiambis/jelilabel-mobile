import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ambang.dart';
import '../../../core/di/injeksi.dart';
import '../../../core/nutri_level.dart';
import '../../../core/theme/tema.dart';
import '../../../core/theme/warna.dart';
import '../../../core/widgets/komponen.dart';
import '../../asupan/asupan_cubit.dart';
import '../../profil/presentation/profil_cubit.dart';
import '../domain/bandingkan_produk.dart';
import 'bandingkan_cubit.dart';

class BandingkanPage extends StatelessWidget {
  const BandingkanPage({super.key, this.awalA, this.awalB});

  final ProdukRingkas? awalA;
  final ProdukRingkas? awalB;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<BandingkanCubit>()..muat(awalA: awalA, awalB: awalB),
        child: const _IsiBandingkan(),
      );
}

class _IsiBandingkan extends StatefulWidget {
  const _IsiBandingkan();

  @override
  State<_IsiBandingkan> createState() => _IsiBandingkanState();
}

class _IsiBandingkanState extends State<_IsiBandingkan> {
  bool _proses = false;

  Future<void> _pilihProduk(BandingkanState state, {required bool untukA}) async {
    if (_proses || state.daftarProduk.isEmpty) return;
    final terpilih = await showModalBottomSheet<ProdukRingkas>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LembarPilihProduk(
        judulLembar: untukA ? 'Pilih produk A' : 'Pilih produk B',
        daftar: state.daftarProduk,
        idTerpilih: untukA ? state.produkA?.id : state.produkB?.id,
      ),
    );
    if (terpilih == null || !mounted) return;
    final cubit = context.read<BandingkanCubit>();
    if (untukA) {
      cubit.pilihA(terpilih);
    } else {
      cubit.pilihB(terpilih);
    }
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
    final messenger = ScaffoldMessenger.of(context);
    final ok = await asupanCubit.catatProduk(produk.id, porsi);
    if (!mounted) return;
    setState(() => _proses = false);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(asupanCubit.state.galat ?? 'Gagal mencatat produk.')));
      return;
    }
    await tampilkanLembarTercatat(context);
  }

  @override
  Widget build(BuildContext context) {
    final profilState = context.watch<ProfilCubit>().state;
    return BlocBuilder<BandingkanCubit, BandingkanState>(
      builder: (context, state) {
        final a = state.produkA;
        final b = state.produkB;
        final hasil = (a != null && b != null)
            ? bandingkanProduk(
                a,
                b,
                batas: profilState.batas,
                fokus: profilState.profil.fokus,
              )
            : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bandingkan'),
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s8, Jarak.layar, Jarak.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.memuat && state.daftarProduk.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: Jarak.s32),
                            child: Center(child: CircularProgressIndicator(color: Warna.hijauTua)),
                          )
                        else if (state.galat != null && state.daftarProduk.isEmpty)
                          KartuPutih(child: Text(state.galat!, style: teksBadan(warna: Warna.tinggiChip)))
                        else if (state.daftarProduk.length < 2)
                          _KurangProduk(jumlahProduk: state.daftarProduk.length)
                        else ...[
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _KartuSlotProduk(
                                    huruf: 'A',
                                    produk: a,
                                    terpilihRingan: hasil?.pilihanLebihRingan == PihakRingan.a,
                                    onTap: _proses ? null : () => _pilihProduk(state, untukA: true),
                                  ),
                                ),
                                const SizedBox(width: Jarak.s12),
                                Expanded(
                                  child: _KartuSlotProduk(
                                    huruf: 'B',
                                    produk: b,
                                    terpilihRingan: hasil?.pilihanLebihRingan == PihakRingan.b,
                                    onTap: _proses ? null : () => _pilihProduk(state, untukA: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Jarak.s16),
                          if (hasil == null)
                            KartuPutih(
                              child: Row(
                                children: [
                                  const Maskot('01-mengintip', ukuran: 64, label: 'Nuri mengintip'),
                                  const SizedBox(width: Jarak.s12),
                                  Expanded(
                                    child: Text(
                                      'Pilih produk A dan produk B dari Produk saya untuk membandingkan gizinya.',
                                      style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            _TabelBandingkan(hasil: hasil),
                            if (hasil.takaranBerbeda) ...[
                              const SizedBox(height: Jarak.s8),
                              Text(
                                'Dibandingkan per sajian label.',
                                style: teksKecil(bobot: FontWeight.w700, warna: Warna.tintaLembut),
                              ),
                            ],
                            const SizedBox(height: Jarak.s16),
                            KartuPutih(
                              padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s12),
                              child: Row(
                                children: [
                                  const Maskot('05-senang', ukuran: 64, label: 'Nuri senang'),
                                  const SizedBox(width: Jarak.s12),
                                  Expanded(
                                    child: Text(
                                      hasil.kalimatRingkas,
                                      style: teksBadan(bobot: FontWeight.w700, tinggi: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                if (hasil != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s12, Jarak.layar, Jarak.s20),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.garis))),
                    child: Row(
                      children: [
                        Expanded(
                          child: hasil.pilihanLebihRingan == PihakRingan.a
                              ? TombolTebal(
                                  label: 'Catat A',
                                  onPressed: _proses ? null : () => _catat(hasil.a),
                                )
                              : TombolTebal.sekunder(
                                  label: 'Catat A',
                                  onPressed: _proses ? null : () => _catat(hasil.a),
                                ),
                        ),
                        const SizedBox(width: Jarak.s12),
                        Expanded(
                          child: hasil.pilihanLebihRingan == PihakRingan.a
                              ? TombolTebal.sekunder(
                                  label: 'Catat B',
                                  onPressed: _proses ? null : () => _catat(hasil.b),
                                )
                              : TombolTebal(
                                  label: 'Catat B',
                                  onPressed: _proses ? null : () => _catat(hasil.b),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KurangProduk extends StatelessWidget {
  const _KurangProduk({required this.jumlahProduk});
  final int jumlahProduk;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Jarak.s24),
        child: Column(
          children: [
            const Maskot('01-mengintip', ukuran: 120, label: 'Nuri mengintip'),
            const SizedBox(height: Jarak.s12),
            Text(
              jumlahProduk == 0
                  ? 'Belum ada produk untuk dibandingkan'
                  : 'Butuh 1 produk lagi untuk dibandingkan',
              style: judulKecil(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Jarak.s8),
            Text(
              'Catat minimal 2 produk dari Beranda agar muncul di daftar bandingkan.',
              style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _KartuSlotProduk extends StatelessWidget {
  const _KartuSlotProduk({
    required this.huruf,
    required this.produk,
    required this.terpilihRingan,
    required this.onTap,
  });

  final String huruf;
  final ProdukRingkas? produk;
  final bool terpilihRingan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = produk;
    final takaran = p == null || p.takaranJumlah == null || p.takaranSatuan == null
        ? null
        : '${angka(p.takaranJumlah!)} ${p.takaranSatuan!}';
    final labelAtas = terpilihRingan ? '$huruf · pilihan lebih ringan' : huruf;

    return Semantics(
      button: true,
      label: p == null ? 'Pilih produk $huruf' : 'Produk $huruf: ${p.nama}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: terpilihRingan ? Warna.oranyeTepi : Warna.garisBayangan,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: terpilihRingan ? Warna.oranyeLembut : Warna.kartu,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: terpilihRingan ? Warna.oranye : Warna.garis,
              width: terpilihRingan ? 2 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Jarak.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          labelAtas,
                          style: teksKecil(
                            bobot: FontWeight.w800,
                            warna: terpilihRingan ? Warna.oranyeTeks : Warna.tintaLembut,
                          ),
                        ),
                      ),
                      const Icon(Icons.swap_horiz_rounded, size: 16, color: Warna.tintaLembut),
                    ],
                  ),
                  const SizedBox(height: Jarak.s4),
                  Text(
                    p?.nama ?? 'Pilih produk $huruf',
                    style: teksBadan(
                      bobot: FontWeight.w800,
                      warna: p == null ? Warna.hijauTua : Warna.tinta,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (takaran != null) ...[
                    const SizedBox(height: Jarak.s4),
                    Text(takaran, style: teksKecil()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabelBandingkan extends StatelessWidget {
  const _TabelBandingkan({required this.hasil});
  final HasilBandingkan hasil;

  @override
  Widget build(BuildContext context) {
    final adaNutriLevel = hasil.nutriLevelA != null || hasil.nutriLevelB != null;
    return Container(
      decoration: BoxDecoration(
        color: Warna.kartu,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Warna.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Warna.permukaanRedup,
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(hasil.judulTakaran, style: teksKecil(bobot: FontWeight.w800)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('A', style: teksKecil(bobot: FontWeight.w800), textAlign: TextAlign.center),
                ),
                Expanded(
                  flex: 2,
                  child: Text('B', style: teksKecil(bobot: FontWeight.w800), textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          for (final r in hasil.baris) ...[
            const Divider(height: 1, color: Warna.garis),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(Jarak.s12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(r.nama, style: teksLabel(bobot: FontWeight.w800)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SelBandingkan(
                      nilai: r.nilaiA,
                      persen: r.persenA,
                      sorot: r.lebihRingan == PihakRingan.a,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SelBandingkan(
                      nilai: r.nilaiB,
                      persen: r.persenB,
                      sorot: r.lebihRingan == PihakRingan.b,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (adaNutriLevel) ...[
            const Divider(height: 1, color: Warna.garis),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(Jarak.s12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Nutri-Level\n(perkiraan)',
                          style: teksKecil(bobot: FontWeight.w800, warna: Warna.tinta),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SelNutriLevel(hasil: hasil.nutriLevelA),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SelNutriLevel(hasil: hasil.nutriLevelB),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelBandingkan extends StatelessWidget {
  const _SelBandingkan({
    required this.nilai,
    required this.persen,
    required this.sorot,
  });

  final String nilai;
  final String? persen;
  final bool sorot;

  @override
  Widget build(BuildContext context) => Container(
        color: sorot ? Warna.oranyeLembut : null,
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s4, vertical: Jarak.s12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(nilai, style: teksBadan(bobot: FontWeight.w800), textAlign: TextAlign.center),
            ),
            if (persen != null) ...[
              const SizedBox(height: Jarak.s4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(persen!, style: teksKecil(), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      );
}

class _SelNutriLevel extends StatelessWidget {
  const _SelNutriLevel({required this.hasil});
  final HasilNutriLevel? hasil;

  @override
  Widget build(BuildContext context) {
    final h = hasil;
    if (h == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Jarak.s12),
          child: Text('-', style: teksBadan(bobot: FontWeight.w800)),
        ),
      );
    }
    final g = gayaNutriLevel(h.level);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Jarak.s8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: g.latar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(h.huruf, style: teksBadan(bobot: FontWeight.w800, warna: g.warnaTeks)),
        ),
      ),
    );
  }
}

class _LembarPilihProduk extends StatefulWidget {
  const _LembarPilihProduk({
    required this.judulLembar,
    required this.daftar,
    this.idTerpilih,
  });

  final String judulLembar;
  final List<ProdukRingkas> daftar;
  final int? idTerpilih;

  @override
  State<_LembarPilihProduk> createState() => _LembarPilihProdukState();
}

class _LembarPilihProdukState extends State<_LembarPilihProduk> {
  final _cari = TextEditingController();
  String _kueri = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  static String _nilai(double? v) => v == null ? '-' : angka(v);

  @override
  Widget build(BuildContext context) {
    final q = _kueri.trim().toLowerCase();
    final hasil = q.isEmpty
        ? widget.daftar
        : [
            for (final p in widget.daftar)
              if (p.nama.toLowerCase().contains(q)) p,
          ];
    final tinggiMaks = MediaQuery.sizeOf(context).height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: tinggiMaks),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Jarak.layar,
          Jarak.s12,
          Jarak.layar,
          Jarak.s16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: Jarak.s4,
                decoration: BoxDecoration(color: Warna.garis, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: Jarak.s12),
            Row(
              children: [
                Expanded(child: Text(widget.judulLembar, style: judulKecil())),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
                ),
              ],
            ),
            const SizedBox(height: Jarak.s8),
            TextField(
              controller: _cari,
              onChanged: (v) => setState(() => _kueri = v),
              style: teksBadan(),
              decoration: InputDecoration(
                hintText: 'Cari produk',
                hintStyle: teksBadan(warna: Warna.tidakDiketahui),
                prefixIcon: const Icon(Icons.search_rounded, color: Warna.tintaLembut),
              ),
            ),
            const SizedBox(height: Jarak.s12),
            Flexible(
              child: hasil.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: Jarak.s20),
                      child: Text(
                        'Produk "${_kueri.trim()}" tidak ditemukan.',
                        style: teksLabel(warna: Warna.tintaLembut),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: hasil.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Jarak.s8),
                      itemBuilder: (context, index) {
                        final p = hasil[index];
                        final aktif = p.id == widget.idTerpilih;
                        final takaran = p.takaranJumlah == null || p.takaranSatuan == null
                            ? null
                            : '${angka(p.takaranJumlah!)} ${p.takaranSatuan!}';
                        final gizi = '${_nilai(p.gulaG)} g gula · ${_nilai(p.natriumMg)} mg natrium · ${_nilai(p.lemakTotalG)} g lemak';
                        return Material(
                          color: aktif ? Warna.oranyeMuda : Warna.kartu,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: aktif ? Warna.oranye : Warna.garis, width: aktif ? 2 : 1),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, p),
                            child: Padding(
                              padding: const EdgeInsets.all(Jarak.s12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.nama,
                                          style: teksBadan(bobot: FontWeight.w800),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (takaran != null) ...[
                                        const SizedBox(width: Jarak.s8),
                                        Text(takaran, style: teksKecil()),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: Jarak.s4),
                                  Text(gizi, style: teksKecil()),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
