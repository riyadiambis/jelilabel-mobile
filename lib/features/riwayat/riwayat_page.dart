import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/ambang.dart';
import '../../core/format.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';
import '../asupan/beranda_page.dart';

sealed class _ItemRiwayat {
  const _ItemRiwayat();
}

class _ItemAtas extends _ItemRiwayat {
  const _ItemAtas();
}

class _ItemHeaderTanggal extends _ItemRiwayat {
  const _ItemHeaderTanggal(this.judulTanggal);
  final String judulTanggal;
}

class _ItemBaris extends _ItemRiwayat {
  const _ItemBaris(this.baris, {required this.pertama, required this.terakhir});
  final BarisRiwayat baris;
  final bool pertama;
  final bool terakhir;
}

class _ItemMemuat extends _ItemRiwayat {
  const _ItemMemuat();
}

enum _ZatRiwayat { gula, natrium, lemak }

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  _ZatRiwayat _zat = _ZatRiwayat.gula;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_saatGulir);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _saatGulir() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<AsupanCubit>().muatLagi();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AsupanCubit>();
    final state = cubit.state;
    final hariIni = state.hariAktif;
    final hari = [for (var i = 6; i >= 0; i--) hariIni.subtract(Duration(days: i))];
    final (batas, satuan, nilai) = switch (_zat) {
      _ZatRiwayat.gula => (batasGulaHarianG, 'g', [for (final h in hari) state.totalGula(h)]),
      _ZatRiwayat.natrium => (batasNatriumHarianMg, 'mg', [for (final h in hari) state.totalNatrium(h)]),
      _ZatRiwayat.lemak => (batasLemakHarianG, 'g', [for (final h in hari) state.totalLemak(h)]),
    };
    final rataRata = nilai.reduce((a, b) => a + b) / nilai.length;

    final kelompok = <DateTime, List<BarisRiwayat>>{};
    for (final k in state.daftar) {
      kelompok.putIfAbsent(k.tanggalLokalObjek, () => []).add(k);
    }

    final items = <_ItemRiwayat>[
      const _ItemAtas(),
      for (final MapEntry(key: tgl, value: daftar) in kelompok.entries) ...[
        _ItemHeaderTanggal(_judulTanggal(tgl, hariIni).toUpperCase()),
        for (final (i, k) in daftar.indexed) _ItemBaris(k, pertama: i == 0, terakhir: i == daftar.length - 1),
      ],
      if (state.memuatLagi) const _ItemMemuat(),
    ];

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _ItemAtas() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Riwayat', style: judul()),
                const SizedBox(height: Jarak.s12),
                _SegmenNutrisi(
                  zatDipilih: _zat,
                  onPilih: (zat) => setState(() => _zat = zat),
                ),
                const SizedBox(height: Jarak.s16),
                KartuPutih(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('7 hari terakhir', style: teksBadan(bobot: FontWeight.w800)),
                          const SizedBox(height: Jarak.s4),
                          Text(
                            'Rata-rata ${angka(rataRata)} $satuan per hari',
                            style: teksLabel(warna: Warna.tintaLembut),
                          ),
                        ]),
                      ),
                      const SizedBox(width: Jarak.s8),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: Jarak.s16, child: _GarisPutus()),
                        const SizedBox(width: Jarak.s4),
                        Text('Batas ${angka(batas)} $satuan', style: teksKecil(bobot: FontWeight.w700)),
                      ]),
                    ]),
                    const SizedBox(height: Jarak.s12),
                    _Grafik(hari: hari, nilai: nilai, batas: batas, satuan: satuan),
                  ]),
                ),
                const SizedBox(height: Jarak.s16),
                if (kelompok.isEmpty && !state.memuat)
                  Padding(
                    padding: const EdgeInsets.only(top: Jarak.s16),
                    child: Text(
                      'Belum ada catatan. Pindai label pertamamu dari Beranda.',
                      style: teksBadan(warna: Warna.tintaLembut),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          _ItemHeaderTanggal(:final judulTanggal) => Padding(
              padding: const EdgeInsets.only(top: Jarak.s8, bottom: Jarak.s8),
              child: Text(judulTanggal, style: teksLabel(bobot: FontWeight.w800, warna: Warna.tintaLembut)),
            ),
          _ItemBaris(:final baris, :final pertama, :final terakhir) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KartuBaris(
                  baris: baris,
                  pertama: pertama,
                  terakhir: terakhir,
                  onKetuk: () => _bukaDetail(context, baris),
                  onHapus: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final terhapus = await cubit.hapus(baris);
                    if (!mounted || terhapus == null) return;
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('${terhapus.nama} dihapus'),
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(label: 'Urungkan', onPressed: () => cubit.kembalikan(terhapus)),
                      ));
                  },
                ),
                if (index == items.length - 1) ...[
                  const SizedBox(height: Jarak.s8),
                  Text(
                    'Ketuk untuk detail. Geser ke kiri untuk hapus.',
                    style: teksKecil(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          _ItemMemuat() => const Padding(
              padding: EdgeInsets.symmetric(vertical: Jarak.s16),
              child: Center(child: CircularProgressIndicator(color: Warna.hijauTua)),
            ),
        };
      },
    );
  }

  String _judulTanggal(DateTime t, DateTime hariIni) {
    final selisih = DateTime.utc(hariIni.year, hariIni.month, hariIni.day)
        .difference(DateTime.utc(t.year, t.month, t.day))
        .inDays;
    if (selisih == 0) return 'Hari ini';
    if (selisih == 1) return 'Kemarin';
    return tanggalPendek(t);
  }

  void _bukaDetail(BuildContext context, BarisRiwayat baris) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Warna.kartu,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LembarDetailKonsumsi(baris: baris),
    );
  }
}

class _SegmenNutrisi extends StatelessWidget {
  const _SegmenNutrisi({required this.zatDipilih, required this.onPilih});
  final _ZatRiwayat zatDipilih;
  final ValueChanged<_ZatRiwayat> onPilih;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: _TombolSegmen(
            label: 'Gula',
            terpilih: zatDipilih == _ZatRiwayat.gula,
            onTap: () => onPilih(_ZatRiwayat.gula),
          ),
        ),
        const SizedBox(width: Jarak.s8),
        Expanded(
          child: _TombolSegmen(
            label: 'Natrium',
            terpilih: zatDipilih == _ZatRiwayat.natrium,
            onTap: () => onPilih(_ZatRiwayat.natrium),
          ),
        ),
        const SizedBox(width: Jarak.s8),
        Expanded(
          child: _TombolSegmen(
            label: 'Lemak',
            terpilih: zatDipilih == _ZatRiwayat.lemak,
            onTap: () => onPilih(_ZatRiwayat.lemak),
          ),
        ),
      ]);
}

class _TombolSegmen extends StatelessWidget {
  const _TombolSegmen({required this.label, required this.terpilih, required this.onTap});
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: terpilih,
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: terpilih ? Warna.oranyeTepi : Warna.garisBayangan,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: terpilih ? Warna.oranyeLembut : Warna.kartu,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: terpilih ? Warna.oranye : Warna.garis, width: terpilih ? 2 : 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (terpilih) ...[
                          const Icon(Icons.check_rounded, size: 18, color: Warna.tinta),
                          const SizedBox(width: Jarak.s4),
                        ],
                        Text(label, style: teksBadan(bobot: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _KartuBaris extends StatelessWidget {
  const _KartuBaris({
    required this.baris,
    required this.pertama,
    required this.terakhir,
    required this.onKetuk,
    required this.onHapus,
  });

  final BarisRiwayat baris;
  final bool pertama;
  final bool terakhir;
  final VoidCallback onKetuk;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    const sisi = BorderSide(color: Warna.garis);
    final radius = BorderRadius.vertical(
      top: pertama ? const Radius.circular(16) : Radius.zero,
      bottom: terakhir ? const Radius.circular(16) : Radius.zero,
    );
    return Container(
      margin: EdgeInsets.only(bottom: terakhir ? Jarak.s8 : 0),
      decoration: BoxDecoration(
        color: Warna.kartu,
        borderRadius: radius,
        border: Border(
          top: pertama ? sisi : BorderSide.none,
          bottom: terakhir ? sisi : BorderSide.none,
          left: sisi,
          right: sisi,
        ),
        boxShadow: terakhir ? const [BoxShadow(color: Warna.garisBayangan, offset: Offset(0, 3))] : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.only(
            left: Jarak.s12,
            right: Jarak.s12,
            top: pertama ? Jarak.s4 : 0,
            bottom: terakhir ? Jarak.s4 : 0,
          ),
          child: Column(
            children: [
              if (!pertama) const Divider(height: 1, color: Warna.jalurBilah),
              Dismissible(
                key: ValueKey(baris.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Jarak.s16),
                  color: Warna.tinggiChip,
                  child: const Icon(Icons.delete_outline_rounded, color: Warna.kartu),
                ),
                onDismissed: (_) => onHapus(),
                child: Semantics(
                  button: true,
                  label: 'Detail ${baris.nama}',
                  child: InkWell(
                    onTap: onKetuk,
                    child: BarisKonsumsi(baris),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LembarDetailKonsumsi extends StatelessWidget {
  const _LembarDetailKonsumsi({required this.baris});
  final BarisRiwayat baris;

  static String _persenTeks(double? nilai, double batas) {
    final p = persenJatah(nilai, batas);
    return p == null ? 'Tidak ada data' : '${(p * 100).round()}% jatah harian';
  }

  @override
  Widget build(BuildContext context) {
    final padanan = [
      if (baris.gulaG != null) 'setara ${teksSendok(sendokGula(baris.gulaG!))} sdm gula',
      if (baris.natriumMg != null) 'setara ${teksSendok(sendokGaram(baris.natriumMg!))} sdt garam',
      if (baris.lemakTotalG != null) 'setara ${teksSendok(sendokMinyak(baris.lemakTotalG!))} sdm minyak',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s12, Jarak.layar, Jarak.s24),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(baris.nama, style: judulKecil(tinggi: 1.2))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
              ),
            ],
          ),
          const SizedBox(height: Jarak.s4),
          Wrap(
            spacing: Jarak.s8,
            runSpacing: Jarak.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${tanggalPendek(baris.waktu)}, ${jam(baris.waktu)} · ${baris.jumlahSajian == 0.5 ? '½' : angka(baris.jumlahSajian)} sajian',
                style: teksLabel(bobot: FontWeight.w600, warna: Warna.tintaLembut),
              ),
              ChipStatus(baris.status),
            ],
          ),
          const SizedBox(height: Jarak.s16),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _PetakNilai(
                  nama: 'Gula',
                  isi: baris.gulaG == null ? '-' : '${angka(baris.gulaG!)} g',
                  persen: _persenTeks(baris.gulaG, batasGulaHarianG),
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: _PetakNilai(
                  nama: 'Natrium',
                  isi: baris.natriumMg == null ? '-' : '${angka(baris.natriumMg!)} mg',
                  persen: _persenTeks(baris.natriumMg, batasNatriumHarianMg),
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: _PetakNilai(
                  nama: 'Lemak',
                  isi: baris.lemakTotalG == null ? '-' : '${angka(baris.lemakTotalG!)} g',
                  persen: _persenTeks(baris.lemakTotalG, batasLemakHarianG),
                ),
              ),
            ]),
          ),
          if (padanan.isNotEmpty) ...[
            const SizedBox(height: Jarak.s12),
            Wrap(
              spacing: Jarak.s12,
              runSpacing: Jarak.s4,
              children: [
                for (final p in padanan)
                  Text(p, style: teksLabel(bobot: FontWeight.w700, warna: Warna.hijauTua)),
              ],
            ),
          ],
          const SizedBox(height: Jarak.s12),
          Text(
            'Nilai dihitung saat dicatat dan tidak berubah bila produk disunting.',
            style: teksKecil(tinggi: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PetakNilai extends StatelessWidget {
  const _PetakNilai({required this.nama, required this.isi, required this.persen});
  final String nama;
  final String isi;
  final String persen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s8),
        decoration: BoxDecoration(
          color: Warna.latar,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Warna.garis),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nama, style: teksKecil(bobot: FontWeight.w800)),
            const SizedBox(height: Jarak.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(isi, style: judulKecil()),
            ),
            const SizedBox(height: Jarak.s4),
            Text(persen, style: teksKecil()),
          ],
        ),
      );
}

class _Grafik extends StatelessWidget {
  const _Grafik({required this.hari, required this.nilai, required this.batas, required this.satuan});
  final List<DateTime> hari;
  final List<double> nilai;
  final double batas;
  final String satuan;

  static const _tinggi = 150.0;

  @override
  Widget build(BuildContext context) {
    final puncak = [batas * 1.4, ...nilai].reduce((a, b) => a > b ? a : b);
    final yBatas = batas / puncak * _tinggi;
    return Semantics(
      label: 'Grafik 7 hari, batas ${angka(batas)} $satuan',
      child: Column(children: [
        Container(
          height: _tinggi + 36,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Warna.garis))),
          child: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: yBatas,
              child: const _GarisPutus(),
            ),
            Positioned.fill(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final (i, v) in nilai.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (v > 0 && (i == nilai.length - 1 || v > batas))
                          FittedBox(
                            child: Text(
                              '${angka(v)} $satuan',
                              style: teksKecil(
                                bobot: FontWeight.w800,
                                warna: v > batas ? Warna.tinggiChip : Warna.tinta,
                              ),
                            ),
                          ),
                        if (v > 0 && (i == nilai.length - 1 || v > batas)) const SizedBox(height: Jarak.s4),
                        if (v <= 0)
                          Container(
                            width: Jarak.s8,
                            height: Jarak.s8,
                            margin: const EdgeInsets.only(bottom: Jarak.s4),
                            decoration: BoxDecoration(
                              color: Warna.jalurBilah,
                              borderRadius: BorderRadius.circular(Jarak.s4),
                            ),
                          )
                        else
                          Container(
                            height: (v / puncak * _tinggi).clamp(Jarak.s8, _tinggi),
                            decoration: BoxDecoration(
                              color: v > batas ? Warna.tinggi : Warna.aman,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(Jarak.s8),
                                bottom: Radius.circular(Jarak.s4),
                              ),
                              border: i == nilai.length - 1 ? Border.all(color: Warna.tinta, width: 2) : null,
                            ),
                          ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: Jarak.s8),
        Row(children: [
          for (final (i, h) in hari.indexed)
            Expanded(
              child: Text(
                hariSingkat(h),
                textAlign: TextAlign.center,
                style: teksKecil(
                  bobot: i == hari.length - 1 ? FontWeight.w800 : FontWeight.w700,
                  warna: i == hari.length - 1 ? Warna.tinta : Warna.tintaLembut,
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _GarisPutus extends StatelessWidget {
  const _GarisPutus();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => Row(
          children: List.generate(
            (c.maxWidth / 8).floor(),
            (_) => Container(width: 4, height: 2, margin: const EdgeInsets.only(right: 4), color: Warna.garisBatas),
          ),
        ),
      );
}
