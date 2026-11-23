import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/format.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import 'asupan_cubit.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> with WidgetsBindingObserver {
  Timer? _timerTengahMalam;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _jadwalkanTengahMalam();
  }

  @override
  void dispose() {
    _timerTengahMalam?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _jadwalkanTengahMalam() {
    _timerTengahMalam?.cancel();
    final cubit = context.read<AsupanCubit>();
    final sekarang = cubit.sekarang;
    final besok = DateTime(sekarang.year, sekarang.month, sekarang.day + 1);
    final jeda = besok.difference(sekarang) + const Duration(milliseconds: 50);
    _timerTengahMalam = Timer(jeda, () {
      if (!mounted) return;
      context.read<AsupanCubit>().segarkan();
      _jadwalkanTengahMalam();
    });
  }

  // Lewat tengah malam saat aplikasi di latar belakang: total harus kembali ke hari baru (FITUR-03 F-05).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      context.read<AsupanCubit>().segarkan();
      _jadwalkanTengahMalam();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AsupanCubit>();
    final state = cubit.state;
    final hari = state.hariAktif;
    final hariIni = state.padaTanggal(hari);
    final ringkasan = state.ringkasan;
    final gula = ringkasan.totalGula;
    final natrium = ringkasan.totalNatrium;
    final statusGula = statusHarian(gula, batasGulaHarianG);
    final statusNatrium = statusHarian(natrium, batasNatriumHarianMg);
    final natriumLebihBuruk = statusNatrium.index > statusGula.index;
    final terburuk = natriumLebihBuruk ? statusNatrium : statusGula;
    final sapaan = switch ((terburuk, natriumLebihBuruk)) {
      (StatusHarian.aman, _) => 'Hari ini masih aman',
      (StatusHarian.hampirBatas, false) => 'Gula hampir batas',
      (StatusHarian.lewatBatas, false) => 'Gula sudah lewat batas',
      (StatusHarian.hampirBatas, true) => 'Natrium hampir batas',
      (StatusHarian.lewatBatas, true) => 'Natrium sudah lewat batas',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.layar, Jarak.layar, Jarak.s24),
      children: [
        if (ringkasan.jumlahCatatan == 0)
          _Kosong(
            tanggal: tanggalPendek(hari),
            sisaKuota: state.sisaKuota,
            plafonKuota: state.plafonKuota,
          )
        else
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    tanggalPendek(hari),
                    style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut),
                  ),
                  const SizedBox(height: Jarak.s4),
                  Text(sapaan, style: judul(tinggi: 1.2)),
                ]),
              ),
              const SizedBox(width: Jarak.s12),
              Maskot(
                terburuk == StatusHarian.hampirBatas ? '06-waspada' : '01-mengintip',
                ukuran: 52,
                label: 'Nuri',
              ),
            ]),
            const SizedBox(height: Jarak.s16),
            if (gula > batasGulaHarianG && cubit.peringatanTerbuka('gula'))
              _Peringatan(
                judulPeringatan: 'Gula hari ini sudah lewat batas Kemenkes',
                saran: 'Minum air putih yuk untuk berikutnya.',
                onTutup: () => cubit.tutupPeringatan('gula'),
              ),
            if (natrium > batasNatriumHarianMg && cubit.peringatanTerbuka('natrium'))
              _Peringatan(
                judulPeringatan: 'Natrium hari ini sudah lewat batas Kemenkes',
                saran: 'Pilih makanan yang tidak asin untuk berikutnya.',
                onTutup: () => cubit.tutupPeringatan('natrium'),
              ),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: _KartuZat(
                    nama: 'Gula',
                    total: gula,
                    satuan: 'g',
                    batas: batasGulaHarianG,
                    tanpaData: ringkasan.jumlahTanpaGula,
                  ),
                ),
                const SizedBox(width: Jarak.s12),
                Expanded(
                  child: _KartuZat(
                    nama: 'Natrium',
                    total: natrium,
                    satuan: 'mg',
                    batas: batasNatriumHarianMg,
                    tanpaData: ringkasan.jumlahTanpaNatrium,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Jarak.s16),
            _AksiPindai(
              sisaKuota: state.sisaKuota,
              plafonKuota: state.plafonKuota,
            ),
            if (hariIni.isNotEmpty) ...[
              const SizedBox(height: Jarak.s20),
              Row(children: [
                Expanded(child: Text('Terakhir dicatat', style: judulKecil())),
                TextButton(
                  onPressed: () => context.go('/riwayat'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: Jarak.s8),
                  ),
                  child: Text('Lihat semua', style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua)),
                ),
              ]),
              const SizedBox(height: Jarak.s4),
              KartuPutih(
                padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s4),
                child: Column(children: [
                  for (final (i, k) in hariIni.take(3).indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Warna.jalurBilah),
                    BarisKonsumsi(k),
                  ],
                ]),
              ),
            ],
          ]),
      ],
    );
  }
}

/// Satu baris konsumsi, dipakai Beranda dan Riwayat.
class BarisKonsumsi extends StatelessWidget {
  const BarisKonsumsi(this.k, {super.key});
  final BarisRiwayat k;

  @override
  Widget build(BuildContext context) {
    final meta = [
      jam(k.waktu),
      if (k.gulaG != null) '${angka(k.gulaG!)} g gula',
      if (k.natriumMg != null) '${angka(k.natriumMg!)} mg natrium',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Jarak.s12),
      child: Row(children: [
        const IkonKemasan(),
        const SizedBox(width: Jarak.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.nama, style: teksBadan(bobot: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              meta,
              style: teksLabel(warna: Warna.tintaLembut),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: Jarak.s8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          ChipStatus(k.status),
          const SizedBox(height: Jarak.s4),
          Text('per porsi', style: teksKecil()),
        ]),
      ]),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({
    required this.tanggal,
    required this.sisaKuota,
    required this.plafonKuota,
  });
  final String tanggal;
  final int sisaKuota;
  final int plafonKuota;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tanggal, style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut)),
        const SizedBox(height: Jarak.s4),
        Text('Belum ada catatan hari ini', style: judul(tinggi: 1.2)),
        const SizedBox(height: Jarak.s16),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Expanded(
              child: _KartuZatKosong(nama: 'Gula', satuan: 'g', batas: batasGulaHarianG),
            ),
            const SizedBox(width: Jarak.s12),
            const Expanded(
              child: _KartuZatKosong(nama: 'Natrium', satuan: 'mg', batas: batasNatriumHarianMg),
            ),
          ]),
        ),
        const SizedBox(height: Jarak.s16),
        Container(
          padding: const EdgeInsets.all(Jarak.s16),
          decoration: BoxDecoration(
            color: Warna.oranyeMuda,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Maskot('02-kaca-pembesar', ukuran: 96, label: 'Nuri memegang kaca pembesar'),
            const SizedBox(width: Jarak.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mulai dari satu label', style: judulKecil()),
                const SizedBox(height: Jarak.s4),
                Text(
                  'Foto tabel gizi minuman atau camilanmu. Nuri hitung gula dan natriumnya.',
                  style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: Jarak.s16),
        _AksiPindai(sisaKuota: sisaKuota, plafonKuota: plafonKuota),
      ]);
}

class _KartuZatKosong extends StatelessWidget {
  const _KartuZatKosong({required this.nama, required this.satuan, required this.batas});
  final String nama;
  final String satuan;
  final double batas;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s12),
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Warna.garis),
          boxShadow: const [BoxShadow(color: Warna.garisBayangan, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nama, style: teksBadan(bobot: FontWeight.w800)),
          const SizedBox(height: Jarak.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '0', style: judulBesar(warna: Warna.tintaLembut)),
              TextSpan(text: ' $satuan', style: teksBadan(bobot: FontWeight.w700, warna: Warna.tintaLembut)),
            ])),
          ),
          const SizedBox(height: Jarak.s8),
          Container(
            height: Jarak.s12,
            decoration: BoxDecoration(
              color: Warna.jalurBilah,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: Jarak.s8),
          Text('Batas ${angka(batas)} $satuan', style: teksLabel(warna: Warna.tintaLembut)),
        ]),
      );
}

class _AksiPindai extends StatefulWidget {
  const _AksiPindai({
    required this.sisaKuota,
    required this.plafonKuota,
  });
  final int sisaKuota;
  final int plafonKuota;

  @override
  State<_AksiPindai> createState() => _AksiPindaiState();
}

class _AksiPindaiState extends State<_AksiPindai> {
  bool _terkunci = false;
  GoRouterDelegate? _delegate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegate = GoRouter.maybeOf(context)?.routerDelegate;
    if (_delegate != delegate) {
      _delegate?.removeListener(_cekKunciSaatKembali);
      _delegate = delegate;
      _delegate?.addListener(_cekKunciSaatKembali);
    }
  }

  @override
  void dispose() {
    _delegate?.removeListener(_cekKunciSaatKembali);
    super.dispose();
  }

  // Pastikan kunci tombol dilepas meski kembali lewat context.go('/beranda') setelah layar galat/isi manual.
  void _cekKunciSaatKembali() {
    if (!_terkunci || !mounted) return;
    final path = _delegate?.currentConfiguration.uri.path;
    final diAtas = ModalRoute.of(context)?.isCurrent ?? false;
    if (path == '/beranda' && diAtas) {
      setState(() => _terkunci = false);
    }
  }

  // Kunci selama alur pindai berjalan: ketuk dua kali tidak membuka dua pemindai (pelajaran Insap).
  Future<void> _pindai() async {
    if (_terkunci) return;
    setState(() => _terkunci = true);
    try {
      await context.push(widget.sisaKuota == 0 ? '/kuota-habis' : '/pindai');
    } finally {
      if (mounted && _terkunci) setState(() => _terkunci = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TombolPindai(
          subjudul: 'Sisa ${widget.sisaKuota} dari ${widget.plafonKuota} minggu ini',
          onPressed: _terkunci ? null : _pindai,
        ),
        const SizedBox(height: Jarak.s12),
        TombolTebal.sekunder(
          label: 'Isi manual tanpa foto',
          ikon: Icons.edit_outlined,
          tinggi: 48,
          onPressed: _terkunci ? null : () => context.push('/cek', extra: DrafProduk.kosong),
        ),
      ]);
}

({String teks, Color latar, Color garis, Color chip, Color teksChip, IconData ikon}) gayaHarian(StatusHarian s) =>
    switch (s) {
      StatusHarian.aman => (
          teks: 'Aman',
          latar: Warna.amanLatar,
          garis: Warna.aman,
          chip: Warna.amanChip,
          teksChip: Warna.kartu,
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
          teksChip: Warna.kartu,
          ikon: Icons.priority_high_rounded
        ),
    };

class _KartuZat extends StatelessWidget {
  const _KartuZat({
    required this.nama,
    required this.total,
    required this.satuan,
    required this.batas,
    required this.tanpaData,
  });
  final String nama;
  final double total;
  final String satuan;
  final double batas;
  final int tanpaData;

  @override
  Widget build(BuildContext context) {
    final g = gayaHarian(statusHarian(total, batas));
    final keteranganSisa = total <= batas
        ? 'Sisa ${angka(batas - total)} $satuan dari ${angka(batas)} $satuan'
        : 'Lewat ${angka(total - batas)} $satuan dari ${angka(batas)} $satuan';
    return Semantics(
      label: '$nama ${angka(total)} $satuan dari ${angka(batas)} $satuan, ${g.teks}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Jarak.s12),
        decoration: BoxDecoration(
          color: g.latar,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: g.garis, width: 2),
          boxShadow: [BoxShadow(color: g.garis, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                nama,
                style: teksBadan(bobot: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Jarak.s4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s4),
                  decoration: BoxDecoration(color: g.chip, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(g.ikon, size: 12, color: g.teksChip),
                    const SizedBox(width: Jarak.s4),
                    Text(g.teks, style: teksKecil(bobot: FontWeight.w800, warna: g.teksChip)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: Jarak.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: angka(total), style: judulBesar(tinggi: 1)),
              TextSpan(text: ' $satuan', style: teksBadan(bobot: FontWeight.w700)),
            ])),
          ),
          const SizedBox(height: Jarak.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (total / batas).clamp(0, 1),
              minHeight: Jarak.s12,
              color: g.garis,
              backgroundColor: Warna.kartu,
            ),
          ),
          const SizedBox(height: Jarak.s8),
          Text(keteranganSisa, style: teksLabel(warna: Warna.tintaLembut)),
          if (tanpaData > 0) ...[
            const SizedBox(height: Jarak.s4),
            Text(
              '$tanpaData produk tanpa data ${nama.toLowerCase()}',
              style: teksKecil(),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan({required this.judulPeringatan, required this.saran, required this.onTutup});
  final String judulPeringatan;
  final String saran;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: Jarak.s12),
        padding: const EdgeInsets.fromLTRB(Jarak.s8, Jarak.s12, Jarak.s4, Jarak.s12),
        decoration: BoxDecoration(color: Warna.tinggiLatar, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Maskot('07-air-putih', ukuran: 72, label: 'Nuri menawarkan air putih'),
          const SizedBox(width: Jarak.s8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Jarak.s4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judulPeringatan, style: teksBadan(bobot: FontWeight.w800, tinggi: 1.3)),
                const SizedBox(height: Jarak.s4),
                Text(saran, style: teksLabel(bobot: FontWeight.w600, warna: Warna.tinggiTeksLembut, tinggi: 1.4)),
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
