import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ambang.dart';
import '../../../core/theme/tema.dart';
import '../../../core/theme/warna.dart';
import '../../../core/widgets/komponen.dart';
import '../domain/profil_batas.dart';
import 'profil_cubit.dart';

/// Layar profil singkat dan batas harian pribadi (`/profil/batas`, U8 / ISSUE-18 / ISSUE-21).
class ProfilBatasPage extends StatefulWidget {
  const ProfilBatasPage({super.key, this.awal = false, this.tambah = false});

  /// True bila dibuka tepat setelah Perkenalan selesai pertama kali.
  final bool awal;

  /// True bila dibuka untuk menambah anggota keluarga baru.
  final bool tambah;

  @override
  State<ProfilBatasPage> createState() => _ProfilBatasPageState();
}

class _ProfilBatasPageState extends State<ProfilBatasPage> {
  int? _profilId;
  KelompokUmur? _umur;
  JenisKelamin? _jenisKelamin;
  FokusZat? _fokus;
  bool _isiSendiri = false;
  late final TextEditingController _cNama = TextEditingController();
  late final TextEditingController _cGula = TextEditingController();
  late final TextEditingController _cNatrium = TextEditingController();
  late final TextEditingController _cLemak = TextEditingController();

  bool _dicobaSimpan = false;
  bool _menyimpan = false;
  bool _sudahInisialisasi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sudahInisialisasi) return;
    _sudahInisialisasi = true;
    if (widget.tambah) {
      _cNama.text = '';
      return;
    }
    final p = context.read<ProfilCubit>().state.profil;
    _profilId = p.id;
    _cNama.text = p.nama;
    _umur = p.umur;
    _jenisKelamin = p.jenisKelamin;
    _fokus = p.fokus;
    _isiSendiri = p.punyaBatasSendiri;
    if (p.batasSendiriGulaG != null) _cGula.text = angka(p.batasSendiriGulaG!);
    if (p.batasSendiriNatriumMg != null) _cNatrium.text = angka(p.batasSendiriNatriumMg!);
    if (p.batasSendiriLemakG != null) _cLemak.text = angka(p.batasSendiriLemakG!);
  }

  @override
  void dispose() {
    _cNama.dispose();
    _cGula.dispose();
    _cNatrium.dispose();
    _cLemak.dispose();
    super.dispose();
  }

  String? get _galatNama {
    final n = _cNama.text.trim();
    if (n.isEmpty) return 'Isi nama profil';
    if (n.length > maksPanjangNamaProfil) return 'Maksimal $maksPanjangNamaProfil huruf';
    return null;
  }

  static double? _bacaAngka(TextEditingController c) {
    final teks = c.text.trim();
    if (teks.isEmpty) return null;
    final v = double.tryParse(teks.replaceAll(',', '.'));
    if (v == null || !v.isFinite) return null;
    return v;
  }

  static String? _galatKolom(TextEditingController c) {
    final teks = c.text.trim();
    if (teks.isEmpty) return null;
    final v = _bacaAngka(c);
    if (v == null || v <= 0) return 'Isi angka lebih dari 0';
    return null;
  }

  String? get _galatPasanganAkg {
    if ((_umur == null) != (_jenisKelamin == null)) {
      return 'Pilih kelompok umur dan jenis kelamin';
    }
    return null;
  }

  String? get _galatBatasSendiriKosong {
    if (!_isiSendiri) return null;
    final adaIsi = _cGula.text.trim().isNotEmpty ||
        _cNatrium.text.trim().isNotEmpty ||
        _cLemak.text.trim().isNotEmpty;
    if (!adaIsi) return 'Isi minimal satu batas harian atau pilih Tidak';
    return null;
  }

  BatasHarian get _pratinjau {
    double? nilaiPositif(TextEditingController c) {
      if (!_isiSendiri) return null;
      final v = _bacaAngka(c);
      return (v != null && v > 0) ? v : null;
    }

    return hitungBatasHarian(
      umur: _umur,
      jenisKelamin: _jenisKelamin,
      batasSendiriGulaG: nilaiPositif(_cGula),
      batasSendiriNatriumMg: nilaiPositif(_cNatrium),
      batasSendiriLemakG: nilaiPositif(_cLemak),
    );
  }

  void _lewati() {
    if (_menyimpan) return;
    if (widget.awal) {
      context.go('/beranda');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profil');
    }
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    setState(() => _dicobaSimpan = true);

    final galatNama = _galatNama;
    final galatAkg = _galatPasanganAkg;
    final galatSendiri = _isiSendiri &&
        (_galatKolom(_cGula) != null ||
            _galatKolom(_cNatrium) != null ||
            _galatKolom(_cLemak) != null ||
            _galatBatasSendiriKosong != null);
    if (galatNama != null || galatAkg != null || galatSendiri) return;

    setState(() => _menyimpan = true);
    final profilBaru = ProfilPengguna(
      id: widget.tambah ? null : _profilId,
      nama: _cNama.text.trim(),
      umur: _umur,
      jenisKelamin: _jenisKelamin,
      fokus: _fokus,
      batasSendiriGulaG: _isiSendiri ? _bacaAngka(_cGula) : null,
      batasSendiriNatriumMg: _isiSendiri ? _bacaAngka(_cNatrium) : null,
      batasSendiriLemakG: _isiSendiri ? _bacaAngka(_cLemak) : null,
    );

    final cubit = context.read<ProfilCubit>();
    final ok = widget.tambah ? await cubit.tambahAnggota(profilBaru) : await cubit.simpan(profilBaru);
    if (!mounted) return;
    if (!ok) {
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(cubit.state.galat ?? 'Gagal menyimpan batas harian.')),
        );
      return;
    }

    if (widget.awal) {
      context.go('/beranda');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profil');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pratinjau = _pratinjau;
    final galatAkg = _dicobaSimpan ? _galatPasanganAkg : null;
    final galatSendiriKosong = _dicobaSimpan ? _galatBatasSendiriKosong : null;

    return PopScope(
      canPop: !_menyimpan,
      child: Scaffold(
        appBar: widget.awal
            ? AppBar(
                automaticallyImplyLeading: false,
                actions: [
                  TextButton(
                    onPressed: _menyimpan ? null : _lewati,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: Jarak.s16),
                    ),
                    child: Text(
                      'Nanti saja',
                      style: teksBadan(bobot: FontWeight.w800, warna: Warna.tintaLembut),
                    ),
                  ),
                ],
              )
            : AppBar(
                title: Text(widget.tambah ? 'Tambah anggota keluarga' : 'Batas harian'),
                leading: IconButton(
                  onPressed: _menyimpan ? null : _lewati,
                  tooltip: 'Kembali',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                actions: widget.tambah
                    ? null
                    : [
                        TextButton(
                          onPressed: _menyimpan ? null : _lewati,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: Jarak.s16),
                          ),
                          child: Text(
                            'Nanti saja',
                            style: teksLabel(bobot: FontWeight.w800, warna: Warna.tintaLembut),
                          ),
                        ),
                      ],
              ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s4, Jarak.layar, Jarak.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Maskot('01-mengintip', ukuran: 64, label: 'Nuri mengintip'),
                          const SizedBox(width: Jarak.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Biar Nuri pas buatmu', style: judul(tinggi: 1.15)),
                                const SizedBox(height: Jarak.s4),
                                Text(
                                  'Atur batas harianmu, bisa diubah kapan saja',
                                  style: teksLabel(warna: Warna.tintaLembut),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Jarak.s20),
                      Text('Nama', style: teksLabel(bobot: FontWeight.w800)),
                      const SizedBox(height: Jarak.s8),
                      TextField(
                        controller: _cNama,
                        onChanged: (_) => setState(() {}),
                        style: teksBadan(bobot: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Ibu, Raka, Saya',
                          hintStyle: teksBadan(warna: Warna.tidakDiketahui),
                          errorText: _dicobaSimpan ? _galatNama : null,
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: Jarak.s16),
                      Text('Kelompok umur', style: teksLabel(bobot: FontWeight.w800)),
                      const SizedBox(height: Jarak.s8),
                      Wrap(
                        spacing: Jarak.s8,
                        runSpacing: Jarak.s8,
                        children: [
                          for (final u in KelompokUmur.values)
                            _ChipPilihan(
                              label: u.kode,
                              terpilih: _umur == u,
                              lebarMin: 72,
                              onTap: _menyimpan
                                  ? null
                                  : () => setState(() => _umur = _umur == u ? null : u),
                            ),
                        ],
                      ),
                      const SizedBox(height: Jarak.s16),
                      Text('Jenis kelamin', style: teksLabel(bobot: FontWeight.w800)),
                      const SizedBox(height: Jarak.s8),
                      Row(
                        children: [
                          Expanded(
                            child: _ChipPilihan(
                              label: JenisKelamin.perempuan.label,
                              terpilih: _jenisKelamin == JenisKelamin.perempuan,
                              onTap: _menyimpan
                                  ? null
                                  : () => setState(
                                        () => _jenisKelamin = _jenisKelamin == JenisKelamin.perempuan
                                            ? null
                                            : JenisKelamin.perempuan,
                                      ),
                            ),
                          ),
                          const SizedBox(width: Jarak.s8),
                          Expanded(
                            child: _ChipPilihan(
                              label: JenisKelamin.lakiLaki.label,
                              terpilih: _jenisKelamin == JenisKelamin.lakiLaki,
                              onTap: _menyimpan
                                  ? null
                                  : () => setState(
                                        () => _jenisKelamin = _jenisKelamin == JenisKelamin.lakiLaki
                                            ? null
                                            : JenisKelamin.lakiLaki,
                                      ),
                            ),
                          ),
                        ],
                      ),
                      if (galatAkg != null) ...[
                        const SizedBox(height: Jarak.s8),
                        Text(galatAkg, style: teksKecil(bobot: FontWeight.w700, warna: Warna.tinggiChip)),
                      ],
                      const SizedBox(height: Jarak.s8),
                      Text(
                        'Batas gula dihitung dari tabel AKG Kemenkes untuk usiamu, paling tinggi 50 g.',
                        style: teksKecil(tinggi: 1.4),
                      ),
                      const SizedBox(height: Jarak.s4),
                      Text(
                        'JeliLabel untuk usia 13 tahun ke atas.',
                        style: teksKecil(tinggi: 1.4),
                      ),
                      const SizedBox(height: Jarak.s20),
                      Text('Yang paling ingin kamu jaga', style: teksLabel(bobot: FontWeight.w800)),
                      const SizedBox(height: Jarak.s8),
                      Row(
                        children: [
                          for (final (i, f) in FokusZat.values.indexed) ...[
                            if (i > 0) const SizedBox(width: Jarak.s8),
                            Expanded(
                              child: _ChipPilihan(
                                label: f.label,
                                terpilih: _fokus == f,
                                onTap: _menyimpan
                                    ? null
                                    : () => setState(() => _fokus = _fokus == f ? null : f),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Jarak.s8),
                      Text(
                        'Kartu ini tampil paling atas di Beranda.',
                        style: teksKecil(tinggi: 1.4),
                      ),
                      const SizedBox(height: Jarak.s20),
                      Text(
                        'Punya batas harian dari dokter atau ahli gizi?',
                        style: teksLabel(bobot: FontWeight.w800),
                      ),
                      const SizedBox(height: Jarak.s8),
                      Row(
                        children: [
                          Expanded(
                            child: _ChipPilihan(
                              label: 'Tidak',
                              terpilih: !_isiSendiri,
                              onTap: _menyimpan ? null : () => setState(() => _isiSendiri = false),
                            ),
                          ),
                          const SizedBox(width: Jarak.s8),
                          Expanded(
                            child: _ChipPilihan(
                              label: 'Ya, isi sendiri',
                              terpilih: _isiSendiri,
                              onTap: _menyimpan ? null : () => setState(() => _isiSendiri = true),
                            ),
                          ),
                        ],
                      ),
                      if (_isiSendiri) ...[
                        const SizedBox(height: Jarak.s12),
                        _KolomBatasSendiri(
                          label: 'Batas gula (opsional)',
                          hintText: '50',
                          satuan: 'g',
                          controller: _cGula,
                          galat: _dicobaSimpan ? _galatKolom(_cGula) : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: Jarak.s12),
                        _KolomBatasSendiri(
                          label: 'Batas natrium (opsional)',
                          hintText: '2000',
                          satuan: 'mg',
                          controller: _cNatrium,
                          galat: _dicobaSimpan ? _galatKolom(_cNatrium) : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: Jarak.s12),
                        _KolomBatasSendiri(
                          label: 'Batas lemak (opsional)',
                          hintText: '67',
                          satuan: 'g',
                          controller: _cLemak,
                          galat: _dicobaSimpan ? _galatKolom(_cLemak) : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (galatSendiriKosong != null) ...[
                          const SizedBox(height: Jarak.s8),
                          Text(
                            galatSendiriKosong,
                            style: teksKecil(bobot: FontWeight.w700, warna: Warna.tinggiChip),
                          ),
                        ],
                      ],
                      const SizedBox(height: Jarak.s8),
                      Text(
                        'Acuan Kemenkes tetap ditampilkan di samping batasmu.',
                        style: teksKecil(tinggi: 1.4),
                      ),
                      const SizedBox(height: Jarak.s20),
                      _KartuPratinjauBatas(batas: pratinjau),
                      const SizedBox(height: Jarak.s16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 18, color: Warna.tintaLembut),
                          const SizedBox(width: Jarak.s8),
                          Expanded(
                            child: Text(
                              'Disimpan hanya di HP ini. Tidak dikirim ke server.',
                              style: teksKecil(tinggi: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s12, Jarak.layar, Jarak.s20),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.garis))),
                child: TombolTebal(
                  label: _menyimpan ? 'Menyimpan...' : 'Simpan',
                  memuat: _menyimpan,
                  onPressed: _menyimpan ? null : _simpan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipPilihan extends StatelessWidget {
  const _ChipPilihan({
    required this.label,
    required this.terpilih,
    required this.onTap,
    this.lebarMin,
  });

  final String label;
  final bool terpilih;
  final VoidCallback? onTap;
  final double? lebarMin;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: terpilih,
        button: true,
        enabled: onTap != null,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 48, minWidth: lebarMin ?? 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (terpilih) ...[
                        const Icon(Icons.check_rounded, size: 16, color: Warna.tinta),
                        const SizedBox(width: Jarak.s4),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: teksLabel(bobot: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _KolomBatasSendiri extends StatelessWidget {
  const _KolomBatasSendiri({
    required this.label,
    required this.hintText,
    required this.satuan,
    required this.controller,
    required this.onChanged,
    this.galat,
  });

  final String label;
  final String hintText;
  final String satuan;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? galat;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: teksLabel(bobot: FontWeight.w700)),
          const SizedBox(height: Jarak.s4),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: teksBadan(bobot: FontWeight.w700),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: teksBadan(warna: Warna.tidakDiketahui),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: Jarak.s12),
                child: Text(satuan, style: teksBadan(bobot: FontWeight.w700, warna: Warna.tintaLembut)),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              errorText: galat,
              errorMaxLines: 2,
            ),
          ),
        ],
      );
}

class _KartuPratinjauBatas extends StatelessWidget {
  const _KartuPratinjauBatas({required this.batas});

  final BatasHarian batas;

  @override
  Widget build(BuildContext context) => KartuPutih(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Pratinjau batas harian', style: teksBadan(bobot: FontWeight.w800)),
                ),
                const SizedBox(width: Jarak.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s4),
                  decoration: BoxDecoration(
                    color: Warna.permukaanRedup,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    batas.sumber.label,
                    style: teksKecil(bobot: FontWeight.w800, warna: Warna.tinta),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Jarak.s12),
            _BarisPratinjau(
              nama: 'Gula',
              nilai: '${angka(batas.gulaG)} g',
              acuan: batas.gulaBerbedaDariKemenkes ? 'Acuan Kemenkes: ${angka(batasGulaHarianG)} g' : null,
            ),
            const SizedBox(height: Jarak.s8),
            _BarisPratinjau(
              nama: 'Natrium',
              nilai: '${angka(batas.natriumMg)} mg',
              acuan: batas.natriumBerbedaDariKemenkes ? 'Acuan Kemenkes: ${angka(batasNatriumHarianMg)} mg' : null,
            ),
            const SizedBox(height: Jarak.s8),
            _BarisPratinjau(
              nama: 'Lemak',
              nilai: '${angka(batas.lemakG)} g',
              acuan: batas.lemakBerbedaDariKemenkes ? 'Acuan Kemenkes: ${angka(batasLemakHarianG)} g' : null,
            ),
          ],
        ),
      );
}

class _BarisPratinjau extends StatelessWidget {
  const _BarisPratinjau({
    required this.nama,
    required this.nilai,
    this.acuan,
  });

  final String nama;
  final String nilai;
  final String? acuan;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(nama, style: teksLabel(bobot: FontWeight.w700))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(nilai, style: teksBadan(bobot: FontWeight.w800)),
              if (acuan != null) Text(acuan!, style: teksKecil()),
            ],
          ),
        ],
      );
}
