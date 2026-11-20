import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/format.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import 'asupan_cubit.dart';

class BerandaPage extends StatelessWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AsupanCubit>();
    final state = cubit.state;
    final hari = cubit.sekarang;
    final hariIni = state.padaTanggal(hari);
    final gula = state.totalGula(hari);
    final natrium = state.totalNatrium(hari);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        HeaderJeli(kanan: Text(tanggalPendek(hari), style: nunito(13, FontWeight.w600, warna: Warna.tintaLembut))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: hariIni.isEmpty
              ? _Kosong(sisaKuota: state.sisaKuota)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 8),
                  if (gula > batasGulaHarianG && cubit.peringatanTerbuka('gula'))
                    _Peringatan(
                      judul: 'Gula hari ini sudah lewat batas Kemenkes',
                      saran: 'Minum air putih yuk untuk berikutnya.',
                      onTutup: () => cubit.tutupPeringatan('gula'),
                    ),
                  if (natrium > batasNatriumHarianMg && cubit.peringatanTerbuka('natrium'))
                    _Peringatan(
                      judul: 'Natrium hari ini sudah lewat batas Kemenkes',
                      saran: 'Pilih makanan yang tidak asin untuk berikutnya.',
                      onTutup: () => cubit.tutupPeringatan('natrium'),
                    ),
                  _Sapaan(statusHarian(gula, batasGulaHarianG)),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _KartuZat(nama: 'Gula', total: gula, satuan: 'g', batas: batasGulaHarianG)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _KartuZat(
                              nama: 'Natrium', total: natrium, satuan: 'mg', batas: batasNatriumHarianMg)),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  _AksiPindai(sisaKuota: state.sisaKuota),
                  const SizedBox(height: 18),
                  Text('Terakhir dicatat', style: fredoka(17)),
                  const SizedBox(height: 8),
                  KartuPutih(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(children: [
                      for (final (i, k) in hariIni.take(3).indexed) ...[
                        if (i > 0) const Divider(height: 1, color: Warna.jalurBilah),
                        BarisKonsumsi(k, keterangan: '${jam(k.waktu)} · ${teksPorsi(k.jumlahSajian)}'),
                      ],
                    ]),
                  ),
                ]),
        ),
      ],
    );
  }
}

String teksPorsi(double s) => s == 0.5 ? '½ sajian' : '${angka(s)} sajian';

/// Satu baris konsumsi, dipakai Beranda dan Riwayat.
class BarisKonsumsi extends StatelessWidget {
  const BarisKonsumsi(this.k, {super.key, required this.keterangan});
  final Konsumsi k;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final nilai = [
      if (k.gulaG != null) '${angka(k.gulaG!)} g gula',
      if (k.natriumMg != null) '${angka(k.natriumMg!)} mg natrium',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const IkonKemasan(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.nama, style: nunito(14, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$keterangan · $nilai',
                style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        ChipStatus(k.status),
      ]),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.sisaKuota});
  final int sisaKuota;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 32),
        const Maskot('02-kaca-pembesar', ukuran: 200, label: 'Nuri memegang kaca pembesar'),
        const SizedBox(height: 12),
        Text('Belum ada catatan hari ini', style: fredoka(24), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Yuk pindai label pertamamu. Nuri bantu hitung gula dan natriumnya.',
            style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.55), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _AksiPindai(sisaKuota: sisaKuota),
      ]);
}

class _AksiPindai extends StatelessWidget {
  const _AksiPindai({required this.sisaKuota});
  final int sisaKuota;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TombolTebal.pindai(
          label: 'Pindai Label Gizi',
          ikon: Icons.photo_camera_outlined,
          onPressed: () => context.push(sisaKuota == 0 ? '/kuota-habis' : '/pindai'),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push('/cek', extra: DrafProduk.kosong),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text('Isi manual', style: nunito(15, FontWeight.w700, warna: Warna.hijauTua)),
            ),
            Text('Sisa pindai minggu ini: $sisaKuota dari ${AsupanState.kuotaGratisMingguan}',
                style: nunito(12, FontWeight.w600, warna: Warna.tintaLembut)),
          ],
        ),
      ]);
}

class _Sapaan extends StatelessWidget {
  const _Sapaan(this.status);
  final StatusHarian status;

  @override
  Widget build(BuildContext context) {
    final kalimat = switch (status) {
      StatusHarian.aman => 'Hari ini masih aman, lanjutkan!',
      StatusHarian.hampirBatas => 'Gula hampir batas. Minuman berikutnya yang tawar ya!',
      StatusHarian.lewatBatas => 'Gula sudah lewat batas. Air putih dulu yuk!',
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      const Maskot('01-mengintip', ukuran: 72),
      const SizedBox(width: 4),
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Warna.kartu,
            border: Border.all(color: Warna.garis),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: Text(kalimat, style: nunito(14, FontWeight.w600, tinggi: 1.45)),
        ),
      ),
    ]);
  }
}

({String teks, Color latar, Color garis, Color chip, Color teksChip, IconData ikon}) gayaHarian(StatusHarian s) =>
    switch (s) {
      StatusHarian.aman => (
          teks: 'Aman',
          latar: Warna.amanLatar,
          garis: Warna.aman,
          chip: Warna.amanChip,
          teksChip: Colors.white,
          ikon: Icons.check_rounded
        ),
      StatusHarian.hampirBatas => (
          teks: 'Hampir batas',
          latar: Warna.waspadaLatar,
          garis: Warna.waspada,
          chip: Warna.waspada,
          teksChip: Warna.tinta,
          ikon: Icons.error_outline_rounded
        ),
      StatusHarian.lewatBatas => (
          teks: 'Lewat batas',
          latar: Warna.tinggiLatar,
          garis: Warna.tinggi,
          chip: Warna.tinggiChip,
          teksChip: Colors.white,
          ikon: Icons.priority_high_rounded
        ),
    };

class _KartuZat extends StatelessWidget {
  const _KartuZat({required this.nama, required this.total, required this.satuan, required this.batas});
  final String nama;
  final double total;
  final String satuan;
  final double batas;

  @override
  Widget build(BuildContext context) {
    final g = gayaHarian(statusHarian(total, batas));
    return Semantics(
      label: '$nama ${angka(total)} $satuan dari ${angka(batas)} $satuan, ${g.teks}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: g.latar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: g.garis, width: 2),
          boxShadow: [BoxShadow(color: g.garis, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nama, style: nunito(14, FontWeight.w800)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: angka(total.roundToDouble()), style: fredoka(34)),
              TextSpan(text: ' $satuan', style: nunito(15, FontWeight.w800)),
            ])),
          ),
          Text('dari ${angka(batas)} $satuan', style: nunito(12, FontWeight.w600, warna: Warna.tintaLembut)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (total / batas).clamp(0, 1),
              minHeight: 10,
              color: g.garis,
              backgroundColor: Warna.kartu,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(color: g.chip, borderRadius: BorderRadius.circular(12)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(g.ikon, size: 18, color: g.teksChip),
                const SizedBox(width: 6),
                Text(g.teks, style: fredoka(15, warna: g.teksChip)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan({required this.judul, required this.saran, required this.onTutup});
  final String judul;
  final String saran;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
        decoration: BoxDecoration(color: Warna.tinggiLatar, borderRadius: BorderRadius.circular(22)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Maskot('07-air-putih', ukuran: 76, label: 'Nuri menawarkan air putih'),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: fredoka(15, tinggi: 1.3)),
                const SizedBox(height: 4),
                Text(saran, style: nunito(13, FontWeight.w600, warna: Warna.tinggiTeksLembut, tinggi: 1.4)),
              ]),
            ),
          ),
          IconButton(
            onPressed: onTutup,
            tooltip: 'Tutup peringatan',
            icon: const Icon(Icons.close_rounded, color: Warna.tinggiTeksLembut),
          ),
        ]),
      );
}
