import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/ambang.dart';
import '../../core/format.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../asupan/asupan_cubit.dart';
import '../asupan/beranda_page.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  bool _gula = true;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AsupanCubit>();
    final state = cubit.state;
    final hariIni = DateTime(cubit.sekarang.year, cubit.sekarang.month, cubit.sekarang.day);
    final hari = [for (var i = 6; i >= 0; i--) hariIni.subtract(Duration(days: i))];
    final batas = _gula ? batasGulaHarianG : batasNatriumHarianMg;
    final nilai = [for (final h in hari) _gula ? state.totalGula(h) : state.totalNatrium(h)];

    final kelompok = <DateTime, List<Konsumsi>>{};
    for (final k in state.daftar) {
      kelompok.putIfAbsent(DateTime(k.waktu.year, k.waktu.month, k.waktu.day), () => []).add(k);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Text('Riwayat', style: fredoka(24)),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Gula')),
          ButtonSegment(value: false, label: Text('Natrium')),
        ],
        selected: {_gula},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _gula = s.first),
        style: SegmentedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          selectedBackgroundColor: Warna.hijauTua,
          selectedForegroundColor: Colors.white,
          textStyle: nunito(14, FontWeight.w800),
          side: const BorderSide(color: Warna.garis, width: 1.5),
        ),
      ),
      const SizedBox(height: 14),
      KartuPutih(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('7 hari terakhir', style: nunito(14, FontWeight.w800))),
            Text('- - Batas ${angka(batas)} ${_gula ? 'g' : 'mg'}',
                style: nunito(12, FontWeight.w600, warna: Warna.tintaLembut)),
          ]),
          Text('${nilai.where((v) => v > batas).length} hari lewat batas',
              style: nunito(12, FontWeight.w600, warna: Warna.tintaLembut)),
          const SizedBox(height: 12),
          _Grafik(hari: hari, nilai: nilai, batas: batas, satuan: _gula ? 'g' : 'mg'),
        ]),
      ),
      const SizedBox(height: 16),
      if (kelompok.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('Belum ada catatan. Pindai label pertamamu dari Beranda.',
              style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut), textAlign: TextAlign.center),
        ),
      for (final MapEntry(key: tgl, value: daftar) in kelompok.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(_judulTanggal(tgl, hariIni).toUpperCase(),
              style: nunito(13, FontWeight.w800, warna: Warna.tintaLembut)),
        ),
        KartuPutih(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final (i, k) in daftar.indexed) ...[
              if (i > 0) const Divider(height: 1, color: Warna.jalurBilah),
              Dismissible(
                key: ObjectKey(k),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Warna.tinggiChip,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) {
                  cubit.hapus(k);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text('${k.nama} dihapus'),
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(label: 'Urungkan', onPressed: () => cubit.kembalikan(k)),
                    ));
                },
                child: BarisKonsumsi(k, keterangan: teksPorsi(k.jumlahSajian)),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }

  String _judulTanggal(DateTime t, DateTime hariIni) {
    final selisih = hariIni.difference(t).inDays;
    if (selisih == 0) return 'Hari ini';
    if (selisih == 1) return 'Kemarin';
    return tanggalPendek(t);
  }
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
        SizedBox(
          // Ruang ekstra di atas batang tertinggi untuk labelnya, juga pada skala huruf besar.
          height: _tinggi + 36,
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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (i == nilai.length - 1 || v > batas)
                          FittedBox(
                            child: Text(angka(v),
                                style: nunito(12, FontWeight.w800, warna: v > batas ? Warna.tinggiChip : Warna.tinta)),
                          ),
                        Container(
                          height: (v / puncak * _tinggi).clamp(2, _tinggi),
                          decoration: BoxDecoration(
                            color: v > batas ? Warna.tinggi : Warna.aman,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
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
        const SizedBox(height: 6),
        Row(children: [
          for (final (i, h) in hari.indexed)
            Expanded(
              child: Text(hariSingkat(h),
                  textAlign: TextAlign.center,
                  style: nunito(12, i == hari.length - 1 ? FontWeight.w800 : FontWeight.w600,
                      warna: i == hari.length - 1 ? Warna.tinta : Warna.tintaLembut)),
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
