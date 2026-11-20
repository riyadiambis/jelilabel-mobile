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
  late final _takaran = TextEditingController(text: _teks(widget.draf.takaranJumlah));
  late final _sajianKemasan = TextEditingController(text: _teks(widget.draf.sajianPerKemasan));
  bool _detailTerbuka = false;
  double _porsi = 1;
  // Pilihan dicatat sebagai label: "1 sajian" dan "Seluruh kemasan" bisa bernilai sama.
  String _pilihan = '1 sajian';
  bool _dicoba = false;

  bool get _manual => widget.draf == DrafProduk.kosong;

  static String _teks(double? x) => x == null ? '' : angka(x);
  static double? _baca(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_nama, _gula, _natrium, _takaran, _sajianKemasan]) {
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

  bool get _keduanyaKosong => _gula.text.trim().isEmpty && _natrium.text.trim().isEmpty;

  String? get _galatSajianKemasan {
    if (_sajianKemasan.text.trim().isEmpty) return null;
    final v = _baca(_sajianKemasan);
    if (v == null || v <= 0) return 'Isi angka lebih dari 0';
    return null;
  }

  void _simpan() {
    setState(() => _dicoba = true);
    final galatDetail = _galatAngka(_takaran) != null || _galatSajianKemasan != null;
    if (galatDetail) setState(() => _detailTerbuka = true);
    if (_galatNama != null ||
        _galatAngka(_gula) != null ||
        _galatAngka(_natrium) != null ||
        _keduanyaKosong ||
        galatDetail) {
      return;
    }
    final draf = DrafProduk(
      nama: _nama.text.trim(),
      gulaG: _baca(_gula),
      natriumMg: _baca(_natrium),
      takaranJumlah: _baca(_takaran),
      takaranSatuan: widget.draf.takaranSatuan,
      sajianPerKemasan: _baca(_sajianKemasan),
    );
    context.read<AsupanCubit>().simpan(draf, _porsi);
    final pesan = ScaffoldMessenger.of(context);
    context.go('/beranda');
    pesan.showSnackBar(const SnackBar(content: Text('Tercatat!')));
  }

  Future<void> _buang() async {
    if (!_manual) {
      final ya = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Buang hasil pindai?', style: fredoka(20)),
          content: Text('Angka yang sudah dibaca Nuri tidak disimpan.', style: nunito(15, FontWeight.w400)),
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
    final sajianKemasan = _baca(_sajianKemasan);
    final porsiPilihan = <(String, double)>[
      ('½ sajian', 0.5),
      ('1 sajian', 1),
      if (sajianKemasan != null && sajianKemasan > 0) ('Seluruh kemasan', sajianKemasan),
    ];
    // "Seluruh kemasan" hilang setelah sajian per kemasan dikosongkan: kembali ke 1 sajian.
    if (!porsiPilihan.any((p) => p.$1 == _pilihan) && _pilihan != 'lain') {
      _pilihan = '1 sajian';
      _porsi = 1;
    }
    final porsiLain = _pilihan == 'lain';

    return PopScope(
      canPop: _manual,
      onPopInvokedWithResult: (sudah, _) {
        if (!sudah) _buang();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_manual ? 'Isi manual' : 'Cek hasil pindai'),
        leading: IconButton(onPressed: _buang, tooltip: 'Kembali', icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
              _Ringkasan(
                nama: _nama.text.trim().isEmpty ? 'Produk baru' : _nama.text.trim(),
                keterangan: _keteranganTakaran(),
                gula: _baca(_gula) == null ? null : _baca(_gula)! * _porsi,
                natrium: _baca(_natrium) == null ? null : _baca(_natrium)! * _porsi,
              ),
              if (!_manual) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Warna.tintaLembut),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Dibaca Nuri dari foto. Cocokkan dengan label ya.',
                        style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut)),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              _Isian(
                label: 'Nama produk',
                controller: _nama,
                galat: _dicoba ? _galatNama : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _Isian(
                    label: 'Gula per sajian',
                    controller: _gula,
                    satuan: 'g',
                    angka: true,
                    galat: _dicoba ? (_galatAngka(_gula) ?? (_keduanyaKosong ? 'Isi gula atau natrium' : null)) : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Isian(
                    label: 'Natrium per sajian',
                    controller: _natrium,
                    satuan: 'mg',
                    angka: true,
                    cekLagi: widget.draf.cekLagiNatrium,
                    galat: _dicoba ? _galatAngka(_natrium) : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (!_detailTerbuka)
                OutlinedButton(
                  onPressed: () => setState(() => _detailTerbuka = true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Warna.garis, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _keteranganTakaran().isEmpty ? 'Takaran saji (opsional)' : _keteranganTakaran(),
                        style: nunito(14, FontWeight.w700),
                      ),
                    ),
                    Text('Ubah', style: nunito(13, FontWeight.w800, warna: Warna.hijauTua)),
                  ]),
                )
              else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: _Isian(
                      label: 'Takaran saji',
                      controller: _takaran,
                      satuan: widget.draf.takaranSatuan ?? 'g',
                      angka: true,
                      galat: _dicoba ? _galatAngka(_takaran) : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Isian(
                      label: 'Sajian per kemasan',
                      controller: _sajianKemasan,
                      angka: true,
                      galat: _dicoba ? _galatSajianKemasan : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
              const SizedBox(height: 16),
              Text('Porsi yang kamu makan atau minum', style: nunito(13, FontWeight.w800)),
              const SizedBox(height: 8),
              GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 52,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (label, nilai) in porsiPilihan)
                    _PilihanPorsi(
                      label: label,
                      terpilih: _pilihan == label,
                      onTap: () => setState(() {
                        _pilihan = label;
                        _porsi = nilai;
                      }),
                    ),
                  _PilihanPorsi(
                    label: porsiLain ? '${angka(_porsi)} sajian' : 'Lainnya…',
                    terpilih: porsiLain,
                    onTap: _porsiLain,
                  ),
                ],
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.garis))),
            child: Row(children: [
              TombolTebal.sekunder(label: 'Buang', onPressed: _buang),
              const SizedBox(width: 10),
              Expanded(child: TombolTebal(label: 'Simpan', onPressed: _simpan)),
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
        title: Text('Berapa sajian?', style: fredoka(20)),
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
  const _Ringkasan({required this.nama, required this.keterangan, required this.gula, required this.natrium});
  final String nama;
  final String keterangan;
  final double? gula;
  final double? natrium;

  @override
  Widget build(BuildContext context) {
    final status = statusPorsi(gula, natrium);
    final g = gayaStatusGizi(status);
    final (latar, garis) = switch (status) {
      StatusGizi.aman => (Warna.amanLatar, Warna.aman),
      StatusGizi.waspada => (Warna.waspadaLatar, Warna.waspada),
      StatusGizi.tinggi => (Warna.tinggiLatar, Warna.tinggi),
      StatusGizi.tidakDiketahui => (Warna.tidakDiketahuiLatar, Warna.tidakDiketahui),
    };
    final sGula = statusZat(gula, batasGulaHarianG);
    final sNatrium = statusZat(natrium, batasNatriumHarianMg);
    final alasan = status == StatusGizi.tidakDiketahui
        ? 'Isi angka gula atau natrium'
        : '${g.teks}, karena ${_peringkat(sGula) >= _peringkat(sNatrium) ? 'gulanya' : 'natriumnya'}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: garis, width: 2),
        boxShadow: [BoxShadow(color: garis, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.local_drink_outlined, size: 28, color: Warna.tinta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nama, style: fredoka(19, tinggi: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (keterangan.isNotEmpty)
                Text(keterangan, style: nunito(13, FontWeight.w400, warna: Warna.tintaLembut)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(color: g.latar, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(g.ikon, size: 18, color: g.warnaTeks),
            const SizedBox(width: 8),
            Flexible(child: Text(alasan, style: fredoka(16, warna: g.warnaTeks), textAlign: TextAlign.center)),
          ]),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _Petak(
                judul: 'Gula',
                persen: persenJatah(gula, batasGulaHarianG),
                takaran: gula == null ? null : '≈ ${teksSendok(gula! / 12.5)} sdm gula',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Petak(
                judul: 'Natrium',
                persen: persenJatah(natrium, batasNatriumHarianMg),
                takaran: natrium == null ? null : '${teksSendok(natrium! / 2000)} sdt garam',
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Petak extends StatelessWidget {
  const _Petak({required this.judul, required this.persen, required this.takaran});
  final String judul;
  final double? persen;
  final String? takaran;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: nunito(12, FontWeight.w800, warna: Warna.tintaLembut)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: persen == null ? '–' : '${(persen! * 100).round()}%', style: fredoka(24, tinggi: 1.2)),
              TextSpan(text: ' jatah harian', style: nunito(12, FontWeight.w600, warna: Warna.tintaLembut)),
            ])),
          ),
          Text(takaran ?? 'Tidak ada di label', style: nunito(12, FontWeight.w400, warna: Warna.tintaLembut)),
        ]),
      );
}

class _Isian extends StatelessWidget {
  const _Isian({
    required this.label,
    required this.controller,
    this.satuan,
    this.angka = false,
    this.cekLagi = false,
    this.galat,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
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
      Text(label, style: nunito(13, FontWeight.w800)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: onChanged,
        style: nunito(angka ? 18 : 16, FontWeight.w700),
        keyboardType: angka ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: angka ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
        decoration: InputDecoration(
          suffixText: satuan,
          suffixStyle: nunito(15, FontWeight.w700, warna: Warna.tintaLembut),
          fillColor: cekLagi ? Warna.oranyeMuda : Warna.kartu,
          enabledBorder: cekLagi ? tepiCek : null,
          errorText: galat,
          errorMaxLines: 2,
        ),
      ),
      if (cekLagi && galat == null) ...[
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, size: 14, color: Warna.oranyeTeks),
          const SizedBox(width: 4),
          Expanded(
            child: Text('Angka ini samar di foto, cek lagi',
                style: nunito(12, FontWeight.w700, warna: Warna.oranyeTeks, tinggi: 1.35)),
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
        child: Material(
          color: terpilih ? Warna.hijauTua : Warna.kartu,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: terpilih ? Warna.hijauTua : Warna.garis, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (terpilih) ...[const Icon(Icons.check_rounded, size: 16, color: Colors.white), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(label,
                        style: nunito(15, terpilih ? FontWeight.w800 : FontWeight.w700,
                            warna: terpilih ? Colors.white : Warna.tinta),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
