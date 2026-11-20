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
  const _ItemHeaderTanggal(this.judul);
  final String judul;
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

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  bool _gula = true;
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
    final batas = _gula ? batasGulaHarianG : batasNatriumHarianMg;
    final nilai = [for (final h in hari) _gula ? state.totalGula(h) : state.totalNatrium(h)];

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _ItemAtas() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                if (kelompok.isEmpty && !state.memuat)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Belum ada catatan. Pindai label pertamamu dari Beranda.',
                        style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut), textAlign: TextAlign.center),
                  ),
              ],
            ),
          _ItemHeaderTanggal(:final judul) => Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(judul, style: nunito(13, FontWeight.w800, warna: Warna.tintaLembut)),
            ),
          _ItemBaris(:final baris, :final pertama, :final terakhir) => _KartuBaris(
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
          _ItemMemuat() => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Warna.kartu,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LembarDetailKonsumsi(baris: baris),
    );
  }
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
      top: pertama ? const Radius.circular(20) : Radius.zero,
      bottom: terakhir ? const Radius.circular(20) : Radius.zero,
    );
    return Container(
      margin: EdgeInsets.only(bottom: terakhir ? 8 : 0),
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
          padding: EdgeInsets.only(left: 14, right: 14, top: pertama ? 4 : 0, bottom: terakhir ? 4 : 0),
          child: Column(
            children: [
              if (!pertama) const Divider(height: 1, color: Warna.jalurBilah),
              Dismissible(
                key: ValueKey(baris.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Warna.tinggiChip,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) => onHapus(),
                child: Semantics(
                  button: true,
                  label: 'Detail ${baris.nama}',
                  child: InkWell(
                    onTap: onKetuk,
                    child: BarisKonsumsi(baris, keterangan: teksPorsi(baris.jumlahSajian)),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Warna.garis, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(baris.nama, style: fredoka(20, tinggi: 1.2))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${tanggalPendek(baris.waktu)}, ${jam(baris.waktu)} · ${teksPorsi(baris.jumlahSajian)}',
                style: nunito(13, FontWeight.w600, warna: Warna.tintaLembut),
              ),
              ChipStatus(baris.status),
            ],
          ),
          const SizedBox(height: 16),
          _PetakTakaran(
            judul: 'Gula',
            nilai: baris.gulaG == null ? 'Tidak ada data gula' : '${angka(baris.gulaG!)} g gula',
            sendok: baris.gulaG == null ? null : 'setara ${teksSendok(sendokGula(baris.gulaG!))} sdm gula',
          ),
          const SizedBox(height: 10),
          _PetakTakaran(
            judul: 'Natrium',
            nilai: baris.natriumMg == null ? 'Tidak ada data natrium' : '${angka(baris.natriumMg!)} mg natrium',
            sendok: baris.natriumMg == null ? null : 'setara ${teksSendok(sendokGaram(baris.natriumMg!))} sdt garam',
          ),
          const SizedBox(height: 14),
          Text(
            'Nilai dihitung saat dicatat dan tidak berubah bila produk disunting.',
            style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PetakTakaran extends StatelessWidget {
  const _PetakTakaran({required this.judul, required this.nilai, this.sendok});
  final String judul;
  final String nilai;
  final String? sendok;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Warna.latar,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Warna.garis),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: nunito(12, FontWeight.w800, warna: Warna.tintaLembut)),
            const SizedBox(height: 4),
            Text(nilai, style: fredoka(18)),
            if (sendok != null) ...[
              const SizedBox(height: 2),
              Text(sendok!, style: nunito(14, FontWeight.w700, warna: Warna.hijauTua)),
            ],
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
