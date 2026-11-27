import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import 'asupan_cubit.dart';

/// Layar Konfirmasi (hasil pindai) dan Isi manual (draf kosong). FITUR-02 F-02, F-03, F-04.
class CekHasilPage extends StatefulWidget {
  const CekHasilPage({super.key, required this.draf});
  final DrafProduk draf;

  @override
  State<CekHasilPage> createState() => _CekHasilPageState();
}

class _CekHasilPageState extends State<CekHasilPage> {
  late final _nama = TextEditingController(text: widget.draf.nama);
  late final _gula = TextEditingController(text: _teks(widget.draf.gulaG));
  late final _natrium = TextEditingController(text: _teks(widget.draf.natriumMg));
  late final _lemak = TextEditingController(text: _teks(widget.draf.lemakTotalG));
  late final _takaran = TextEditingController(text: _teks(widget.draf.takaranJumlah));
  late final _sajianKemasan = TextEditingController(text: _teks(widget.draf.sajianPerKemasan));
  bool _detailTerbuka = false;
  double _porsi = 1;
  // Pilihan dicatat sebagai label: '½', '1', '2', atau 'lain'.
  String _pilihan = '1';
  bool _dicoba = false;
  bool _menyimpan = false;

  bool get _manual => widget.draf == DrafProduk.kosong;

  bool get _formulirKosong =>
      _nama.text.trim().isEmpty &&
      _gula.text.trim().isEmpty &&
      _natrium.text.trim().isEmpty &&
      _lemak.text.trim().isEmpty &&
      _takaran.text.trim().isEmpty &&
      _sajianKemasan.text.trim().isEmpty;

  bool get _adaAngka => _baca(_gula) != null || _baca(_natrium) != null || _baca(_lemak) != null;

  static String _teks(double? x) => x == null ? '' : angka(x);
  static double? _baca(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_nama, _gula, _natrium, _lemak, _takaran, _sajianKemasan]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _galatNama {
    final n = _nama.text.trim();
    if (n.isEmpty) return 'Isi nama produk';
    if (n.length > 60) return 'Maksimal 60 huruf';
    return null;
  }

  String? _galatAngka(TextEditingController c) {
    if (c.text.trim().isEmpty) return null;
    final v = _baca(c);
    if (v == null || v < 0) return 'Isi angka 0 atau lebih';
    return null;
  }

  String? get _galatSajianKemasan {
    if (_sajianKemasan.text.trim().isEmpty) return null;
    final v = _baca(_sajianKemasan);
    if (v == null || v <= 0) return 'Isi angka lebih dari 0';
    return null;
  }

  Future<void> _simpan() async {
    if (_menyimpan || !_adaAngka) return;
    setState(() => _dicoba = true);
    final galatDetail = _galatAngka(_takaran) != null || _galatSajianKemasan != null;
    if (galatDetail) setState(() => _detailTerbuka = true);
    if (_galatNama != null ||
        _galatAngka(_gula) != null ||
        _galatAngka(_natrium) != null ||
        _galatAngka(_lemak) != null ||
        !_adaAngka ||
        galatDetail) {
      return;
    }
    setState(() => _menyimpan = true);
    final draf = DrafProduk(
      nama: _nama.text.trim(),
      gulaG: _baca(_gula),
      natriumMg: _baca(_natrium),
      lemakTotalG: _baca(_lemak),
      takaranJumlah: _baca(_takaran),
      takaranSatuan: widget.draf.takaranSatuan,
      sajianPerKemasan: _baca(_sajianKemasan),
    );
    final berhasil = await context.read<AsupanCubit>().simpan(
          draf,
          _porsi,
          sumber: _manual ? 'manual' : 'pindai',
        );
    if (!mounted) return;
    if (!berhasil) {
      setState(() => _menyimpan = false);
      final galat = context.read<AsupanCubit>().state.galat ?? 'Gagal menyimpan catatan';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(galat)));
      return;
    }
    final rootNav = Navigator.of(context, rootNavigator: true);
    context.go('/beranda');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootNav.mounted) return;
      showModalBottomSheet<void>(
        context: rootNav.context,
        useRootNavigator: true,
        backgroundColor: Warna.kartu,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _LembarTercatat(),
      );
    });
  }

  Future<void> _buang() async {
    if (!_manual) {
      final ya = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Buang hasil pindai?', style: judulKecil()),
          content: Text('Angka yang sudah dibaca Nuri tidak disimpan.', style: teksBadan()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Buang')),
          ],
        ),
      );
      if (ya != true || !mounted) return;
    }
    context.pop();
  }

  Future<void> _porsiLain() async {
    final hasil = await showDialog<double>(context: context, builder: (_) => const _DialogPorsi());
    if (hasil == null || !mounted) return;
    setState(() {
      _porsi = hasil;
      _pilihan = 'lain';
    });
  }

  @override
  Widget build(BuildContext context) {
    final porsiPilihan = <(String, double)>[
      ('½', 0.5),
      ('1', 1),
      ('2', 2),
    ];
    final porsiLain = _pilihan == 'lain';

    return PopScope(
      canPop: _manual && !_menyimpan,
      onPopInvokedWithResult: (sudah, _) {
        if (!sudah && !_menyimpan) _buang();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_manual ? 'Isi manual' : 'Cek hasil pindai'),
          leading: IconButton(onPressed: _buang, tooltip: 'Kembali', icon: const Icon(Icons.arrow_back_rounded)),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s8, Jarak.layar, Jarak.s16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!_manual) ...[
                    Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Warna.tintaLembut),
                      const SizedBox(width: Jarak.s8),
                      Expanded(
                        child: Text(
                          'Dibaca Nuri dari foto. Cocokkan dengan label ya.',
                          style: teksLabel(warna: Warna.tintaLembut),
                        ),
                      ),
                    ]),
                    const SizedBox(height: Jarak.s12),
                  ],
                  _Isian(
                    label: 'Nama produk',
                    hintText: 'Contoh: teh botol 350 ml',
                    controller: _nama,
                    galat: _dicoba ? _galatNama : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Jarak.s16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: _Isian(
                        label: 'Gula',
                        hintText: '0',
                        bantu: 'per sajian, sesuai label',
                        controller: _gula,
                        satuan: 'g',
                        angka: true,
                        cekLagi: widget.draf.cekLagiGula,
                        galat: _dicoba ? (_galatAngka(_gula) ?? (!_adaAngka ? 'Isi gula, natrium, atau lemak' : null)) : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Jarak.s12),
                    Expanded(
                      child: _Isian(
                        label: 'Natrium',
                        hintText: '0',
                        bantu: 'per sajian, sesuai label',
                        controller: _natrium,
                        satuan: 'mg',
                        angka: true,
                        cekLagi: widget.draf.cekLagiNatrium,
                        galat: _dicoba ? _galatAngka(_natrium) : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ]),
                  const SizedBox(height: Jarak.s12),
                  _Isian(
                    label: 'Lemak',
                    hintText: '0',
                    bantu: 'per sajian, sesuai label',
                    controller: _lemak,
                    satuan: 'g',
                    angka: true,
                    cekLagi: widget.draf.cekLagiLemak,
                    galat: _dicoba ? _galatAngka(_lemak) : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Jarak.s16),
                  Text('Berapa yang kamu makan atau minum?', style: teksLabel(bobot: FontWeight.w800)),
                  const SizedBox(height: Jarak.s8),
                  Row(children: [
                    for (final (label, nilai) in porsiPilihan) ...[
                      Expanded(
                        child: _PilihanPorsi(
                          label: label,
                          terpilih: _pilihan == label,
                          onTap: () => setState(() {
                            _pilihan = label;
                            _porsi = nilai;
                          }),
                        ),
                      ),
                      const SizedBox(width: Jarak.s8),
                    ],
                    Expanded(
                      child: _PilihanPorsi(
                        label: porsiLain ? angka(_porsi) : 'Lain',
                        terpilih: porsiLain,
                        onTap: _porsiLain,
                      ),
                    ),
                  ]),
                  const SizedBox(height: Jarak.s16),
                  if (!_detailTerbuka)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _detailTerbuka = true),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                _keteranganTakaran().isEmpty ? 'Takaran saji (opsional)' : _keteranganTakaran(),
                                style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut),
                              ),
                            ),
                            Text(
                              _keteranganTakaran().isEmpty ? 'Tambah' : 'Ubah',
                              style: teksLabel(bobot: FontWeight.w800, warna: Warna.hijauTua),
                            ),
                          ]),
                        ),
                      ),
                    )
                  else
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: _Isian(
                          label: 'Takaran saji',
                          hintText: '0',
                          controller: _takaran,
                          satuan: widget.draf.takaranSatuan ?? 'g',
                          angka: true,
                          galat: _dicoba ? _galatAngka(_takaran) : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Jarak.s12),
                      Expanded(
                        child: _Isian(
                          label: 'Sajian per kemasan',
                          hintText: '0',
                          controller: _sajianKemasan,
                          angka: true,
                          galat: _dicoba ? _galatSajianKemasan : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ]),
                  const SizedBox(height: Jarak.s16),
                  if (_manual && !_adaAngka)
                    const _KotakGarisPutus()
                  else
                    _Ringkasan(
                      nama: _nama.text.trim().isEmpty ? 'Produk baru' : _nama.text.trim(),
                      keterangan: _keteranganTakaran(),
                      gula: _baca(_gula) == null ? null : _baca(_gula)! * _porsi,
                      natrium: _baca(_natrium) == null ? null : _baca(_natrium)! * _porsi,
                      lemak: _baca(_lemak) == null ? null : _baca(_lemak)! * _porsi,
                      teksKosong: _manual ? 'Tidak diisi' : 'Tidak ada di label',
                    ),
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s12, Jarak.layar, Jarak.s20),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.garis))),
              child: Row(children: [
                Expanded(
                  flex: 1,
                  child: (_manual && _formulirKosong)
                      ? TombolTebal.sekunder(
                          label: 'Batal',
                          onPressed: _menyimpan ? null : _buang,
                        )
                      : TombolTebal.bahaya(
                          label: 'Buang',
                          ikon: Icons.delete_outline_rounded,
                          onPressed: _menyimpan ? null : _buang,
                        ),
                ),
                const SizedBox(width: Jarak.s12),
                Expanded(
                  flex: 2,
                  child: TombolTebal(
                    label: _menyimpan ? 'Menyimpan...' : 'Simpan',
                    onPressed: (_menyimpan || !_adaAngka) ? null : _simpan,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  String _keteranganTakaran() {
    final t = _baca(_takaran);
    final s = _baca(_sajianKemasan);
    return [
      if (t != null) 'Takaran saji ${angka(t)} ${widget.draf.takaranSatuan ?? 'g'}',
      if (s != null) '${angka(s)} sajian per kemasan',
    ].join(' · ');
  }
}

class _LembarTercatat extends StatefulWidget {
  const _LembarTercatat();

  @override
  State<_LembarTercatat> createState() => _LembarTercatatState();
}

class _LembarTercatatState extends State<_LembarTercatat> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      // Pengguna bisa menutup lembar sendiri tepat sebelum 2 detik; jangan pop rute di bawahnya.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Jarak.s24, Jarak.s24, Jarak.s24, Jarak.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Maskot('05-senang', ukuran: 120, label: 'Nuri senang')),
            const SizedBox(height: Jarak.s12),
            Text('Tercatat!', style: judul(), textAlign: TextAlign.center),
            const SizedBox(height: Jarak.s4),
            Text(
              'Asupan hari ini sudah diperbarui.',
              style: teksLabel(warna: Warna.tintaLembut),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _KotakGarisPutus extends StatelessWidget {
  const _KotakGarisPutus();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const _PainterGarisPutus(),
        child: Padding(
          padding: const EdgeInsets.all(Jarak.s16),
          child: Row(children: [
            const Icon(Icons.bar_chart_rounded, size: 28, color: Warna.tintaLembut),
            const SizedBox(width: Jarak.s12),
            Expanded(
              child: Text(
                'Isi angka gula, natrium, atau lemak. Status dan bagian jatah harianmu muncul di sini.',
                style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
              ),
            ),
          ]),
        ),
      );
}

class _PainterGarisPutus extends CustomPainter {
  const _PainterGarisPutus();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Warna.garis
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    const segmen = 6.0;
    const spasi = 4.0;
    for (final metrik in path.computeMetrics()) {
      var jarak = 0.0;
      while (jarak < metrik.length) {
        final akhir = (jarak + segmen).clamp(0.0, metrik.length);
        canvas.drawPath(metrik.extractPath(jarak, akhir), paint);
        jarak += segmen + spasi;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

int _peringkat(StatusGizi s) => s == StatusGizi.tidakDiketahui ? -1 : s.index;

/// Dialog porsi bebas. Controller hidup di State dialog, jadi dibuang setelah dialog benar-benar hilang.
class _DialogPorsi extends StatefulWidget {
  const _DialogPorsi();

  @override
  State<_DialogPorsi> createState() => _DialogPorsiState();
}

class _DialogPorsiState extends State<_DialogPorsi> {
  final _c = TextEditingController();
  String? _galat;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pakai() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 20) {
      setState(() => _galat = 'Isi angka lebih dari 0, maksimal 20');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Berapa sajian?', style: judulKecil()),
        content: TextField(
          controller: _c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'mis. 1,5', errorText: _galat, errorMaxLines: 2),
          onSubmitted: (_) => _pakai(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: _pakai, child: const Text('Pakai')),
        ],
      );
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({
    required this.nama,
    required this.keterangan,
    required this.gula,
    required this.natrium,
    required this.lemak,
    required this.teksKosong,
  });
  final String nama;
  final String keterangan;
  final double? gula;
  final double? natrium;
  final double? lemak;
  final String teksKosong;

  @override
  Widget build(BuildContext context) {
    final status = statusPorsi(gula, natrium, lemak);
    final g = gayaStatusGizi(status);
    final (latar, garis) = switch (status) {
      StatusGizi.aman => (Warna.amanLatar, Warna.aman),
      StatusGizi.waspada => (Warna.waspadaLatar, Warna.waspada),
      StatusGizi.tinggi => (Warna.tinggiLatar, Warna.tinggi),
      StatusGizi.tidakDiketahui => (Warna.tidakDiketahuiLatar, Warna.tidakDiketahui),
    };
    final penyebab = [
      ('gulanya', statusZat(gula, batasGulaHarianG)),
      ('natriumnya', statusZat(natrium, batasNatriumHarianMg)),
      ('lemaknya', statusZat(lemak, batasLemakHarianG)),
    ].reduce((a, b) => _peringkat(b.$2) > _peringkat(a.$2) ? b : a);
    final alasan = status == StatusGizi.tidakDiketahui
        ? 'Isi angka gula, natrium, atau lemak'
        : '${g.teks}, karena ${penyebab.$1}';

    return Container(
      padding: const EdgeInsets.all(Jarak.s16),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: garis, width: 2),
        boxShadow: [BoxShadow(color: garis, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IkonKemasan(ukuran: 48),
          const SizedBox(width: Jarak.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nama, style: judulKecil(tinggi: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (keterangan.isNotEmpty)
                Text(keterangan, style: teksLabel(warna: Warna.tintaLembut)),
            ]),
          ),
        ]),
        const SizedBox(height: Jarak.s12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: Jarak.s8, horizontal: Jarak.s12),
          decoration: BoxDecoration(color: g.latar, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(g.ikon, size: 18, color: g.warnaTeks),
            const SizedBox(width: Jarak.s8),
            Flexible(
              child: Text(
                alasan,
                style: teksBadan(bobot: FontWeight.w800, warna: g.warnaTeks),
                textAlign: TextAlign.center,
              ),
            ),
          ]),
        ),
        const SizedBox(height: Jarak.s12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _Petak(
                judulPetak: 'Gula',
                persen: persenJatah(gula, batasGulaHarianG),
                takaran: gula == null ? null : '≈ ${teksSendok(sendokGula(gula!))} sdm gula',
                teksKosong: teksKosong,
              ),
            ),
            const SizedBox(width: Jarak.s8),
            Expanded(
              child: _Petak(
                judulPetak: 'Natrium',
                persen: persenJatah(natrium, batasNatriumHarianMg),
                takaran: natrium == null ? null : '${teksSendok(sendokGaram(natrium!))} sdt garam',
                teksKosong: teksKosong,
              ),
            ),
            const SizedBox(width: Jarak.s8),
            Expanded(
              child: _Petak(
                judulPetak: 'Lemak',
                persen: persenJatah(lemak, batasLemakHarianG),
                takaran: lemak == null ? null : '≈ ${teksSendok(sendokMinyak(lemak!))} sdm minyak',
                teksKosong: teksKosong,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Petak extends StatelessWidget {
  const _Petak({required this.judulPetak, required this.persen, required this.takaran, required this.teksKosong});
  final String judulPetak;
  final String teksKosong;
  final double? persen;
  final String? takaran;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s8),
        decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judulPetak, style: teksKecil(bobot: FontWeight.w800)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: persen == null ? '–' : '${(persen! * 100).round()}%', style: judul(tinggi: 1.2)),
              TextSpan(text: ' jatah harian', style: teksKecil(bobot: FontWeight.w600)),
            ])),
          ),
          Text(takaran ?? teksKosong, style: teksKecil()),
        ]),
      );
}

class _Isian extends StatelessWidget {
  const _Isian({
    required this.label,
    required this.controller,
    this.hintText,
    this.bantu,
    this.satuan,
    this.angka = false,
    this.cekLagi = false,
    this.galat,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? bantu;
  final String? satuan;
  final bool angka;
  final bool cekLagi;
  final String? galat;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tepiCek = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Warna.oranye, width: 2),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: teksLabel(bobot: FontWeight.w800)),
      const SizedBox(height: Jarak.s4),
      TextField(
        controller: controller,
        onChanged: onChanged,
        style: teksBadan(bobot: FontWeight.w700),
        keyboardType: angka ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: angka ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: teksBadan(warna: Warna.tidakDiketahui),
          suffixIcon: satuan == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: Jarak.s12),
                  child: Text(satuan!, style: teksBadan(bobot: FontWeight.w700, warna: Warna.tintaLembut)),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          fillColor: cekLagi ? Warna.oranyeMuda : Warna.kartu,
          enabledBorder: cekLagi ? tepiCek : null,
          errorText: galat,
          errorMaxLines: 2,
        ),
      ),
      if (bantu != null && galat == null && !cekLagi) ...[
        const SizedBox(height: Jarak.s4),
        Text(bantu!, style: teksKecil(bobot: FontWeight.w600)),
      ],
      if (cekLagi && galat == null) ...[
        const SizedBox(height: Jarak.s4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, size: 14, color: Warna.oranyeTeks),
          const SizedBox(width: Jarak.s4),
          Expanded(
            child: Text(
              'Angka ini samar di foto, cek lagi',
              style: teksKecil(bobot: FontWeight.w700, warna: Warna.oranyeTeks, tinggi: 1.35),
            ),
          ),
        ]),
      ],
    ]);
  }
}

class _PilihanPorsi extends StatelessWidget {
  const _PilihanPorsi({required this.label, required this.terpilih, required this.onTap});
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
            boxShadow: terpilih ? const [BoxShadow(color: Warna.oranyeTepi, offset: Offset(0, 3))] : const [],
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (terpilih) ...[
                          const Icon(Icons.check_rounded, size: 16, color: Warna.tinta),
                          const SizedBox(width: Jarak.s4),
                        ],
                        Text(label, style: teksLabel(bobot: terpilih ? FontWeight.w800 : FontWeight.w700)),
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
