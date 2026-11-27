import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/ambang.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../aktivitas/presentation/aktivitas_cubit.dart';
import '../barcode/presentation/lembar_barcode.dart';
import '../pengingat/presentation/pengingat_cubit.dart';
import '../profil/domain/profil_batas.dart';
import '../profil/presentation/profil_cubit.dart';
import '../tantangan/domain/jenis_tantangan.dart';
import '../tantangan/presentation/tantangan_cubit.dart';
import 'asupan_cubit.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key, this.pemicuBarcode});

  final ValueNotifier<bool>? pemicuBarcode;

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> with WidgetsBindingObserver, RouteAware {
  Timer? _timerTengahMalam;
  GoRouterDelegate? _delegate;
  ModalRoute<void>? _ruteTerdaftar;
  bool _sedangTampilUcapan = false;
  bool _sedangBarcodeWidget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.pemicuBarcode?.addListener(_jadwalkanCekBarcodeWidget);
    _jadwalkanTengahMalam();
    _jadwalkanCekUcapan();
    _jadwalkanCekBarcodeWidget();
  }

  @override
  void didUpdateWidget(covariant BerandaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pemicuBarcode != widget.pemicuBarcode) {
      oldWidget.pemicuBarcode?.removeListener(_jadwalkanCekBarcodeWidget);
      widget.pemicuBarcode?.addListener(_jadwalkanCekBarcodeWidget);
      _jadwalkanCekBarcodeWidget();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rute = ModalRoute.of(context);
    if (_ruteTerdaftar != rute) {
      if (_ruteTerdaftar != null) pengamatRute.unsubscribe(this);
      _ruteTerdaftar = rute;
      if (rute != null) pengamatRute.subscribe(this, rute);
    }
    final delegate = GoRouter.maybeOf(context)?.routerDelegate;
    if (_delegate != delegate) {
      _delegate?.removeListener(_jadwalkanCekUcapan);
      _delegate = delegate;
      _delegate?.addListener(_jadwalkanCekUcapan);
    }
  }

  @override
  void dispose() {
    widget.pemicuBarcode?.removeListener(_jadwalkanCekBarcodeWidget);
    if (_ruteTerdaftar != null) pengamatRute.unsubscribe(this);
    _delegate?.removeListener(_jadwalkanCekUcapan);
    _timerTengahMalam?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _jadwalkanCekBarcodeWidget() {
    if (widget.pemicuBarcode?.value != true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jalankanBarcodeWidget();
    });
  }

  Future<void> _jalankanBarcodeWidget() async {
    final pemicu = widget.pemicuBarcode;
    if (pemicu == null || !pemicu.value || !mounted || _sedangBarcodeWidget) return;
    final rute = ModalRoute.of(context);
    if (rute == null || !rute.isCurrent) return;
    pemicu.value = false;
    _sedangBarcodeWidget = true;
    try {
      await jalankanAlurBarcode(context);
    } finally {
      _sedangBarcodeWidget = false;
    }
  }

  @override
  void didPopNext() {
    _jadwalkanCekUcapan();
    _jadwalkanCekBarcodeWidget();
  }

  void _jadwalkanCekUcapan() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cekTampilkanUcapan();
    });
  }

  Future<void> _cekTampilkanUcapan() async {
    if (!mounted || _sedangTampilUcapan) return;
    final rute = ModalRoute.of(context);
    if (rute == null || !rute.isCurrent) return;
    final path = _delegate?.currentConfiguration.uri.path;
    if (path != null && path != '/beranda') return;

    final tantanganCubit = context.read<TantanganCubit>();
    final ucapan = tantanganCubit.state.ucapanTercapai;
    if (ucapan == null) return;

    _sedangTampilUcapan = true;
    await tantanganCubit.tandaiUcapanTercapai(ucapan.id);
    if (!mounted) {
      _sedangTampilUcapan = false;
      return;
    }
    try {
      await tampilkanLembarTantanganTercapai(context, ucapan.jenis.judul);
    } finally {
      _sedangTampilUcapan = false;
    }
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
      context.read<TantanganCubit>().muat();
      context.read<AktivitasCubit>().muat();
      _jadwalkanTengahMalam();
    });
  }

  // Lewat tengah malam saat aplikasi di latar belakang: total harus kembali ke hari baru (FITUR-03 F-05).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      context.read<AsupanCubit>().segarkan();
      context.read<TantanganCubit>().muat();
      context.read<AktivitasCubit>().muat();
      context.read<PengingatCubit>().jadwalkanUlang();
      _jadwalkanTengahMalam();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AsupanCubit>();
    final profilState = context.watch<ProfilCubit>().state;
    final batas = profilState.batas;
    final fokus = profilState.profil.fokus;
    final tantanganState = context.watch<TantanganCubit>().state;
    final aktivitasState = context.watch<AktivitasCubit>().state;
    final langkahHariIni = aktivitasState.terhubung ? aktivitasState.langkahHariIni : null;
    final state = cubit.state;
    final hari = state.hariAktif;
    final hariIni = state.padaTanggal(hari);
    final ringkasan = state.ringkasan;
    final gula = ringkasan.totalGula;
    final natrium = ringkasan.totalNatrium;
    final lemak = ringkasan.totalLemak;
    final daftarStatus = [
      (nama: 'Gula', status: statusHarian(gula, batas.gulaG)),
      (nama: 'Natrium', status: statusHarian(natrium, batas.natriumMg)),
      (nama: 'Lemak', status: statusHarian(lemak, batas.lemakG)),
    ];
    final terburuk = daftarStatus.reduce((a, b) => b.status.index > a.status.index ? b : a);
    final sapaan = switch (terburuk.status) {
      StatusHarian.aman => 'Hari ini masih aman',
      StatusHarian.hampirBatas => '${terburuk.nama} hampir batas',
      StatusHarian.lewatBatas => '${terburuk.nama} sudah lewat batas',
    };

    final peringatanAktif = <({String judul, String saran, VoidCallback onTutup})>[
      if (gula > batas.gulaG && cubit.peringatanTerbuka('gula'))
        (
          judul: batas.gulaBerbedaDariKemenkes
              ? 'Gula hari ini sudah lewat batas harian'
              : 'Gula hari ini sudah lewat batas Kemenkes',
          saran: 'Minum air putih yuk untuk berikutnya.',
          onTutup: () => cubit.tutupPeringatan('gula'),
        ),
      if (natrium > batas.natriumMg && cubit.peringatanTerbuka('natrium'))
        (
          judul: batas.natriumBerbedaDariKemenkes
              ? 'Natrium hari ini sudah lewat batas harian'
              : 'Natrium hari ini sudah lewat batas Kemenkes',
          saran: 'Pilih makanan yang tidak asin untuk berikutnya.',
          onTutup: () => cubit.tutupPeringatan('natrium'),
        ),
      if (lemak > batas.lemakG && cubit.peringatanTerbuka('lemak'))
        (
          judul: batas.lemakBerbedaDariKemenkes
              ? 'Lemak hari ini sudah lewat batas harian'
              : 'Lemak hari ini sudah lewat batas Kemenkes',
          saran: 'Pilih makanan yang tidak berminyak untuk berikutnya.',
          onTutup: () => cubit.tutupPeringatan('lemak'),
        ),
    ];

    return BlocListener<TantanganCubit, TantanganState>(
      listenWhen: (sebelum, sesudah) =>
          sebelum.ucapanTercapai != sesudah.ucapanTercapai && sesudah.ucapanTercapai != null,
      listener: (_, _) => _jadwalkanCekUcapan(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.layar, Jarak.layar, Jarak.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderBeranda(
              tanggal: tanggalPendek(hari),
              namaProfil: profilState.profil.nama,
              subjudul: ringkasan.jumlahCatatan == 0 ? 'Belum ada catatan hari ini' : sapaan,
              waspada: ringkasan.jumlahCatatan > 0 && terburuk.status == StatusHarian.hampirBatas,
              onGantiProfil: () => _bukaLembarProfil(context),
            ),
            const SizedBox(height: Jarak.s16),
            if (ringkasan.jumlahCatatan == 0)
              _Kosong(
                sisaKuota: state.sisaKuota,
                plafonKuota: state.plafonKuota,
                produkSering: state.produkSering,
                tantanganBerjalan: tantanganState.berjalan,
                langkahHariIni: langkahHariIni,
                batas: batas,
                fokus: fokus,
              )
            else
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _KartuGgl(
                  gula: gula,
                  natrium: natrium,
                  lemak: lemak,
                  batas: batas,
                  fokus: fokus,
                  tanpaGula: ringkasan.jumlahTanpaGula,
                  tanpaNatrium: ringkasan.jumlahTanpaNatrium,
                  tanpaLemak: ringkasan.jumlahTanpaLemak,
                ),
                if (peringatanAktif.isNotEmpty) ...[
                  const SizedBox(height: Jarak.s12),
                  _KartuPeringatan(daftar: peringatanAktif),
                ],
                if (langkahHariIni != null) ...[
                  const SizedBox(height: Jarak.s8),
                  _BarisLangkahHariIni(langkah: langkahHariIni),
                ],
                const SizedBox(height: Jarak.s16),
                _AksiPindai(
                  sisaKuota: state.sisaKuota,
                  plafonKuota: state.plafonKuota,
                ),
                if (state.produkSering.isNotEmpty) ...[
                  const SizedBox(height: Jarak.s20),
                  _CatatCepat(produk: state.produkSering),
                ],
                const SizedBox(height: Jarak.s20),
                _KartuTantanganBeranda(berjalan: tantanganState.berjalan),
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
        ),
      ),
    );
  }

  Future<void> _bukaLembarProfil(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Warna.kartu,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _LembarPilihProfil(),
      );
}

/// Satu baris konsumsi, dipakai Beranda dan Riwayat.
class BarisKonsumsi extends StatelessWidget {
  const BarisKonsumsi(this.k, {super.key});
  final BarisRiwayat k;

  @override
  Widget build(BuildContext context) {
    final batas = context.watch<ProfilCubit>().state.batas;
    final meta = [
      jam(k.waktu),
      if (k.gulaG != null) '${angka(k.gulaG!)} g gula',
      if (k.natriumMg != null) '${angka(k.natriumMg!)} mg natrium',
      if (k.lemakTotalG != null) '${angka(k.lemakTotalG!)} g lemak',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Jarak.s12),
      child: Row(children: [
        IkonKemasan(satuan: k.takaranSatuan),
        const SizedBox(width: Jarak.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.nama, style: teksBadan(bobot: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              meta,
              style: teksLabel(warna: Warna.tintaLembut),
            ),
          ]),
        ),
        const SizedBox(width: Jarak.s8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          ChipStatus(k.statusUntuk(batas)),
          const SizedBox(height: Jarak.s4),
          Text('per porsi', style: teksKecil()),
        ]),
      ]),
    );
  }
}

class _HeaderBeranda extends StatelessWidget {
  const _HeaderBeranda({
    required this.tanggal,
    required this.namaProfil,
    required this.subjudul,
    required this.waspada,
    required this.onGantiProfil,
  });

  final String tanggal;
  final String namaProfil;
  final String subjudul;
  final bool waspada;
  final VoidCallback onGantiProfil;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tanggal,
                      style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut),
                    ),
                    const SizedBox(height: Jarak.s4),
                    Text(
                      'Hai, $namaProfil!',
                      style: judul(tinggi: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Semantics(
                button: true,
                label: 'Ganti profil',
                excludeSemantics: true,
                child: Material(
                  color: Warna.kartu,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: Warna.garis, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onGantiProfil,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44, maxWidth: 152),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Jarak.s4, Jarak.s4, Jarak.s8, Jarak.s4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Maskot(waspada ? '06-waspada' : '01-mengintip', ukuran: 36),
                            const SizedBox(width: Jarak.s4),
                            Flexible(
                              child: Text(
                                namaProfil,
                                style: teksLabel(bobot: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Jarak.s4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Warna.tinta),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Jarak.s4),
          Text(
            subjudul,
            style: teksLabel(bobot: FontWeight.w700, warna: Warna.tintaLembut),
          ),
        ],
      );
}

class _LembarPilihProfil extends StatefulWidget {
  const _LembarPilihProfil();

  @override
  State<_LembarPilihProfil> createState() => _LembarPilihProfilState();
}

class _LembarPilihProfilState extends State<_LembarPilihProfil> {
  bool _proses = false;

  Future<void> _pilih(int id) async {
    if (_proses) return;
    setState(() => _proses = true);
    final cubit = context.read<ProfilCubit>();
    await cubit.pilihProfil(id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profilState = context.watch<ProfilCubit>().state;
    final daftar = profilState.daftarProfil.isEmpty
        ? [profilState.profil]
        : profilState.daftarProfil;

    return SafeArea(
      child: SingleChildScrollView(
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
              children: [
                Expanded(child: Text('Pilih profil', style: judulKecil())),
                IconButton(
                  onPressed: _proses ? null : () => Navigator.pop(context),
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
                ),
              ],
            ),
            const SizedBox(height: Jarak.s8),
            Container(
              decoration: BoxDecoration(
                color: Warna.kartu,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Warna.garis),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, p) in daftar.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Warna.jalurBilah),
                    _BarisPilihProfil(
                      profil: p,
                      aktif: daftar.length == 1 || p.id == profilState.profil.id,
                      onTap: (_proses || p.id == null || p.id == profilState.profil.id)
                          ? null
                          : () => _pilih(p.id!),
                    ),
                  ],
                ],
              ),
            ),
            if (profilState.daftarProfil.length < maksProfilKeluarga) ...[
              const SizedBox(height: Jarak.s12),
              TombolTebal.sekunder(
                label: 'Tambah anggota keluarga',
                ikon: Icons.add_rounded,
                onPressed: _proses
                    ? null
                    : () {
                        Navigator.pop(context);
                        context.push('/profil/batas?tambah=1');
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarisPilihProfil extends StatelessWidget {
  const _BarisPilihProfil({
    required this.profil,
    required this.aktif,
    required this.onTap,
  });

  final ProfilPengguna profil;
  final bool aktif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: aktif ? Warna.oranyeMuda : Warna.kartu,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Warna.permukaanRedup,
                      shape: BoxShape.circle,
                    ),
                    child: Text(profil.hurufAwal, style: judulKecil()),
                  ),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profil.nama,
                          style: teksBadan(bobot: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profil.keteranganSingkat,
                          style: teksLabel(warna: Warna.tintaLembut),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (aktif) ...[
                    const SizedBox(width: Jarak.s8),
                    Text('Aktif', style: teksKecil(bobot: FontWeight.w800, warna: Warna.hijauTua)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _Kosong extends StatelessWidget {
  const _Kosong({
    required this.sisaKuota,
    required this.plafonKuota,
    required this.produkSering,
    required this.batas,
    this.fokus,
    this.tantanganBerjalan,
    this.langkahHariIni,
  });
  final int sisaKuota;
  final int plafonKuota;
  final List<ProdukRingkas> produkSering;
  final BatasHarian batas;
  final FokusZat? fokus;
  final KemajuanTantangan? tantanganBerjalan;
  final int? langkahHariIni;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _KartuGgl(gula: 0, natrium: 0, lemak: 0, batas: batas, fokus: fokus),
        if (langkahHariIni != null) ...[
          const SizedBox(height: Jarak.s8),
          _BarisLangkahHariIni(langkah: langkahHariIni!),
        ],
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
                  'Foto tabel gizi minuman atau camilanmu. Nuri hitung gula, natrium, dan lemaknya.',
                  style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: Jarak.s16),
        _AksiPindai(sisaKuota: sisaKuota, plafonKuota: plafonKuota),
        if (produkSering.isNotEmpty) ...[
          const SizedBox(height: Jarak.s20),
          _CatatCepat(produk: produkSering),
        ],
        const SizedBox(height: Jarak.s20),
        _KartuTantanganBeranda(berjalan: tantanganBerjalan),
      ]);
}

class _BarisLangkahHariIni extends StatelessWidget {
  const _BarisLangkahHariIni({required this.langkah});

  final int langkah;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Warna.garis),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_walk_rounded, size: 18, color: Warna.tinta),
            const SizedBox(width: Jarak.s8),
            Expanded(
              child: Text(
                'Langkah hari ini: ${ribuan(langkah)}',
                style: teksLabel(bobot: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _KartuTantanganBeranda extends StatelessWidget {
  const _KartuTantanganBeranda({required this.berjalan});

  final KemajuanTantangan? berjalan;

  @override
  Widget build(BuildContext context) {
    final b = berjalan;
    if (b == null) {
      return Semantics(
        button: true,
        label: 'Mulai tantangan',
        child: Material(
          color: Warna.kartu,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Warna.garis),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/tantangan'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: Warna.tinta, size: 24),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Text('Mulai tantangan', style: teksLabel(bobot: FontWeight.w800)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Tantangan: ${b.jenis.judul}, ${b.terpenuhi} dari ${b.target}',
      child: Material(
        color: Warna.oranyeMuda,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/tantangan'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
            child: Row(
              children: [
                const Maskot('05-senang', ukuran: 48),
                const SizedBox(width: Jarak.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tantangan: ${b.jenis.judul}',
                        style: teksLabel(bobot: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Jarak.s8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: b.target * 32.0),
                        child: Row(
                          children: [
                            for (var i = 0; i < b.target; i++) ...[
                              if (i > 0) const SizedBox(width: Jarak.s4),
                              Expanded(
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i < b.terpenuhi ? Warna.oranye : Warna.jalurBilah,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Jarak.s12),
                Text('${b.terpenuhi}/${b.target}', style: judulKecil()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatatCepat extends StatefulWidget {
  const _CatatCepat({required this.produk});
  final List<ProdukRingkas> produk;

  @override
  State<_CatatCepat> createState() => _CatatCepatState();
}

class _CatatCepatState extends State<_CatatCepat> {
  bool _menyimpan = false;

  Future<void> _catat(ProdukRingkas p) async {
    if (_menyimpan) return;
    setState(() => _menyimpan = true);
    final cubit = context.read<AsupanCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await cubit.catatProduk(p.id, 1);
    if (!mounted) return;
    setState(() => _menyimpan = false);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(cubit.state.galat ?? 'Gagal mencatat produk.')));
      return;
    }
    await tampilkanLembarTercatat(context);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Catat ulang sekali ketuk', style: teksBadan(bobot: FontWeight.w800)),
          const SizedBox(height: Jarak.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, p) in widget.produk.take(3).indexed) ...[
                  if (i > 0) const SizedBox(width: Jarak.s8),
                  Semantics(
                    button: true,
                    enabled: !_menyimpan,
                    label: 'Catat ulang ${p.nama}',
                    child: Material(
                      color: _menyimpan ? Warna.jalurBilah : Warna.kartu,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(color: Warna.garis, width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: _menyimpan ? null : () => _catat(p),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: Jarak.s12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: _menyimpan ? Warna.tintaLembut : Warna.hijauTua,
                              ),
                              const SizedBox(width: Jarak.s8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  p.nama,
                                  style: teksLabel(
                                    bobot: FontWeight.w700,
                                    warna: _menyimpan ? Warna.tintaLembut : Warna.tinta,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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

  Future<void> _pindaiBarcode() async {
    if (_terkunci) return;
    setState(() => _terkunci = true);
    try {
      await jalankanAlurBarcode(context);
    } finally {
      if (mounted && _terkunci) setState(() => _terkunci = false);
    }
  }

  Future<void> _isiManual() async {
    if (_terkunci) return;
    setState(() => _terkunci = true);
    try {
      await context.push('/cek', extra: DrafProduk.kosong);
    } finally {
      if (mounted && _terkunci) setState(() => _terkunci = false);
    }
  }

  Future<void> _bandingkan() async {
    if (_terkunci) return;
    setState(() => _terkunci = true);
    try {
      await context.push('/bandingkan');
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
        Row(
          children: [
            Expanded(
              child: _TombolAksiBeranda(
                label: 'Barcode',
                ikon: Icons.qr_code_scanner_rounded,
                onPressed: _terkunci ? null : _pindaiBarcode,
              ),
            ),
            const SizedBox(width: Jarak.s8),
            Expanded(
              child: _TombolAksiBeranda(
                label: 'Bandingkan',
                ikon: Icons.compare_arrows_rounded,
                onPressed: _terkunci ? null : _bandingkan,
              ),
            ),
            const SizedBox(width: Jarak.s8),
            Expanded(
              child: _TombolAksiBeranda(
                label: 'Isi manual',
                ikon: Icons.edit_outlined,
                onPressed: _terkunci ? null : _isiManual,
              ),
            ),
          ],
        ),
      ]);
}

class _TombolAksiBeranda extends StatelessWidget {
  const _TombolAksiBeranda({
    required this.label,
    required this.ikon,
    required this.onPressed,
  });

  final String label;
  final IconData ikon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    final warnaIsi = aktif ? Warna.tinta : Warna.tintaLembut;
    return Semantics(
      button: true,
      enabled: aktif,
      child: Material(
        color: aktif ? Warna.kartu : Warna.jalurBilah,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Warna.garis, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Warna.garis, width: 3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ikon, size: 20, color: warnaIsi),
                const SizedBox(height: Jarak.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: teksLabel(bobot: FontWeight.w800, warna: warnaIsi),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({String teks, Color latar, Color garis, Color chip, Color teksChip, IconData ikon}) gayaHarian(StatusHarian s) =>
    switch (s) {
      StatusHarian.aman => (
          teks: 'Aman',
          latar: Warna.amanLatar,
          garis: Warna.aman,
          chip: Warna.amanLatar,
          teksChip: Warna.amanChip,
          ikon: Icons.check_rounded
        ),
      StatusHarian.hampirBatas => (
          teks: 'Hampir batas',
          latar: Warna.waspadaLatar,
          garis: Warna.waspada,
          chip: Warna.waspadaLatar,
          teksChip: Warna.waspadaChip,
          ikon: Icons.error_outline_rounded
        ),
      StatusHarian.lewatBatas => (
          teks: 'Lewat batas',
          latar: Warna.tinggiLatar,
          garis: Warna.tinggi,
          chip: Warna.tinggiLatar,
          teksChip: Warna.tinggiChip,
          ikon: Icons.priority_high_rounded
        ),
    };

class _KartuGgl extends StatelessWidget {
  const _KartuGgl({
    required this.gula,
    required this.natrium,
    required this.lemak,
    required this.batas,
    this.fokus,
    this.tanpaGula = 0,
    this.tanpaNatrium = 0,
    this.tanpaLemak = 0,
  });

  final double gula;
  final double natrium;
  final double lemak;
  final BatasHarian batas;
  final FokusZat? fokus;
  final int tanpaGula;
  final int tanpaNatrium;
  final int tanpaLemak;

  @override
  Widget build(BuildContext context) {
    final urutan = switch (fokus) {
      FokusZat.natrium => const [FokusZat.natrium, FokusZat.gula, FokusZat.lemak],
      FokusZat.lemak => const [FokusZat.lemak, FokusZat.gula, FokusZat.natrium],
      FokusZat.gula || null => const [FokusZat.gula, FokusZat.natrium, FokusZat.lemak],
    };

    Widget baris(FokusZat z) => switch (z) {
          FokusZat.gula => _BarisGgl(
              nama: 'Gula',
              total: gula,
              satuan: 'g',
              batas: batas.gulaG,
              acuanKemenkes: batas.gulaBerbedaDariKemenkes
                  ? 'Acuan Kemenkes: ${angka(batasGulaHarianG)} g'
                  : null,
              tanpaData: tanpaGula,
            ),
          FokusZat.natrium => _BarisGgl(
              nama: 'Natrium',
              total: natrium,
              satuan: 'mg',
              batas: batas.natriumMg,
              acuanKemenkes: batas.natriumBerbedaDariKemenkes
                  ? 'Acuan Kemenkes: ${angka(batasNatriumHarianMg)} mg'
                  : null,
              tanpaData: tanpaNatrium,
            ),
          FokusZat.lemak => _BarisGgl(
              nama: 'Lemak',
              total: lemak,
              satuan: 'g',
              batas: batas.lemakG,
              acuanKemenkes: batas.lemakBerbedaDariKemenkes
                  ? 'Acuan Kemenkes: ${angka(batasLemakHarianG)} g'
                  : null,
              tanpaData: tanpaLemak,
            ),
        };

    return KartuPutih(
      padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
      child: Column(children: [
        for (final (i, z) in urutan.indexed) ...[
          if (i > 0) const SizedBox(height: Jarak.s12),
          baris(z),
        ],
      ]),
    );
  }
}

class _BarisGgl extends StatelessWidget {
  const _BarisGgl({
    required this.nama,
    required this.total,
    required this.satuan,
    required this.batas,
    required this.tanpaData,
    this.acuanKemenkes,
  });

  final String nama;
  final double total;
  final String satuan;
  final double batas;
  final int tanpaData;
  final String? acuanKemenkes;

  @override
  Widget build(BuildContext context) {
    final g = gayaHarian(statusHarian(total, batas));
    return Semantics(
      label: '$nama ${angka(total)} $satuan dari ${angka(batas)} $satuan, ${g.teks}',
      excludeSemantics: true,
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
          const SizedBox(width: Jarak.s8),
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${angka(total)} $satuan', style: judulKecil(tinggi: 1.1)),
                    TextSpan(text: ' / ${angka(batas)} $satuan', style: teksLabel(warna: Warna.tintaLembut)),
                  ])),
                ),
                if (acuanKemenkes != null)
                  Text(
                    acuanKemenkes!,
                    style: teksKecil(),
                    textAlign: TextAlign.end,
                  ),
              ],
            ),
          ),
          const SizedBox(width: Jarak.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s4),
            decoration: BoxDecoration(color: g.chip, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(g.ikon, size: 12, color: g.teksChip),
              const SizedBox(width: Jarak.s4),
              Text(g.teks, style: teksKecil(bobot: FontWeight.w800, warna: g.teksChip)),
            ]),
          ),
        ]),
        const SizedBox(height: Jarak.s4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: (total / batas).clamp(0, 1),
            minHeight: 10,
            color: g.garis,
            backgroundColor: Warna.jalurBilah,
          ),
        ),
        if (tanpaData > 0) ...[
          const SizedBox(height: Jarak.s4),
          Text(
            '$tanpaData produk tanpa data ${nama.toLowerCase()}',
            style: teksKecil(),
          ),
        ],
      ]),
    );
  }
}

class _KartuPeringatan extends StatelessWidget {
  const _KartuPeringatan({required this.daftar});
  final List<({String judul, String saran, VoidCallback onTutup})> daftar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(Jarak.s8, Jarak.s12, Jarak.s4, Jarak.s12),
        decoration: BoxDecoration(color: Warna.tinggiLatar, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Maskot('07-air-putih', ukuran: daftar.length > 1 ? 56 : 72, label: 'Nuri menawarkan air putih'),
            const SizedBox(width: Jarak.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, item) in daftar.indexed) ...[
                    if (i > 0) const Divider(height: Jarak.s12, color: Warna.bahayaGaris),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: Jarak.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.judul, style: teksBadan(bobot: FontWeight.w800, tinggi: 1.3)),
                                const SizedBox(height: Jarak.s4),
                                Text(
                                  item.saran,
                                  style: teksLabel(bobot: FontWeight.w600, warna: Warna.tinggiTeksLembut, tinggi: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: item.onTutup,
                          tooltip: 'Tutup peringatan',
                          icon: const Icon(Icons.close_rounded, color: Warna.tinggiTeksLembut),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
