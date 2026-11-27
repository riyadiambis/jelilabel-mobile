import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/ambang.dart';
import '../../core/di/injeksi.dart';
import '../../core/format.dart';
import '../../core/theme/tema.dart';
import '../../core/theme/warna.dart';
import '../../core/widgets/komponen.dart';
import '../aktivitas/domain/sesi_olahraga.dart';
import '../aktivitas/presentation/aktivitas_cubit.dart';
import '../asupan/asupan_cubit.dart';
import '../asupan/beranda_page.dart';
import '../bagikan/data_kartu_bagikan.dart';
import '../bagikan/kartu_bagikan.dart';
import '../profil/presentation/profil_cubit.dart';
import 'riwayat_cubit.dart';

sealed class _ItemRiwayat {
  const _ItemRiwayat();
}

class _ItemAtas extends _ItemRiwayat {
  const _ItemAtas();
}

class _ItemHeaderTanggal extends _ItemRiwayat {
  const _ItemHeaderTanggal(this.judulTanggal, {this.nilaiHariIni});
  final String judulTanggal;
  final String? nilaiHariIni;
}

class _ItemBaris extends _ItemRiwayat {
  const _ItemBaris(this.baris, {required this.pertama, required this.terakhir});
  final BarisRiwayat baris;
  final bool pertama;
  final bool terakhir;
}

class _ItemSesiOlahraga extends _ItemRiwayat {
  const _ItemSesiOlahraga(this.sesi);
  final SesiOlahraga sesi;
}

class _ItemMemuat extends _ItemRiwayat {
  const _ItemMemuat();
}

enum _ZatRiwayat { gula, natrium, lemak }

class RiwayatPage extends StatelessWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<RiwayatCubit>()..muatGrafik(),
        child: const _IsiRiwayat(),
      );
}

class _IsiRiwayat extends StatefulWidget {
  const _IsiRiwayat();

  @override
  State<_IsiRiwayat> createState() => _IsiRiwayatState();
}

class _IsiRiwayatState extends State<_IsiRiwayat> {
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
    final riwayatCubit = context.watch<RiwayatCubit>();
    final riwayatState = riwayatCubit.state;
    final aktivitasState = context.watch<AktivitasCubit>().state;
    final batasAktif = context.watch<ProfilCubit>().state.batas;
    final hariIni = state.hariAktif;
    final daftarHari = riwayatState.daftarHari;

    final (batas, satuan, nilai, totalHariIni) = switch (_zat) {
      _ZatRiwayat.gula => (
          batasAktif.gulaG,
          'g',
          [for (final h in daftarHari) riwayatState.totalGula(h)],
          state.ringkasan.totalGula,
        ),
      _ZatRiwayat.natrium => (
          batasAktif.natriumMg,
          'mg',
          [for (final h in daftarHari) riwayatState.totalNatrium(h)],
          state.ringkasan.totalNatrium,
        ),
      _ZatRiwayat.lemak => (
          batasAktif.lemakG,
          'g',
          [for (final h in daftarHari) riwayatState.totalLemak(h)],
          state.ringkasan.totalLemak,
        ),
    };

    final rataRata = nilai.isEmpty ? 0.0 : nilai.reduce((a, b) => a + b) / nilai.length;
    final jumlahLewat = nilai.where((v) => v > 0 && statusHarian(v, batas) == StatusHarian.lewatBatas).length;
    final jumlahHampir = nilai.where((v) => v > 0 && statusHarian(v, batas) == StatusHarian.hampirBatas).length;
    final statusRingkasan = jumlahLewat > 0
        ? 'Lewat batas $jumlahLewat hari'
        : jumlahHampir > 0
            ? 'Hampir batas $jumlahHampir hari'
            : 'Aman, 0 hari lewat batas';

    final kelompok = <DateTime, List<BarisRiwayat>>{};
    for (final k in state.daftar) {
      kelompok.putIfAbsent(k.tanggalLokalObjek, () => []).add(k);
    }
    final kelompokSesi = <DateTime, List<SesiOlahraga>>{};
    if (aktivitasState.terhubung) {
      for (final s in aktivitasState.sesi) {
        kelompokSesi.putIfAbsent(s.tanggalLokalObjek, () => []).add(s);
      }
    }
    final semuaTanggal = <DateTime>{...kelompok.keys, ...kelompokSesi.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    final teksHariIni = 'Hari ini: ${angka(totalHariIni)} $satuan';
    final items = <_ItemRiwayat>[
      const _ItemAtas(),
      if (!semuaTanggal.any((t) => hariSama(t, hariIni)))
        _ItemHeaderTanggal('HARI INI', nilaiHariIni: teksHariIni),
      for (final tgl in semuaTanggal) ...[
        _ItemHeaderTanggal(
          _judulTanggal(tgl, hariIni).toUpperCase(),
          nilaiHariIni: hariSama(tgl, hariIni) ? teksHariIni : null,
        ),
        for (final (i, k) in (kelompok[tgl] ?? const <BarisRiwayat>[]).indexed)
          _ItemBaris(k, pertama: i == 0, terakhir: i == (kelompok[tgl]!.length - 1)),
        for (final s in kelompokSesi[tgl] ?? const <SesiOlahraga>[]) _ItemSesiOlahraga(s),
      ],
      if (state.memuatLagi) const _ItemMemuat(),
    ];

    return BlocListener<AsupanCubit, AsupanState>(
      listenWhen: (sebelum, sesudah) =>
          sebelum.daftar != sesudah.daftar ||
          sebelum.ringkasan != sesudah.ringkasan ||
          !hariSama(sebelum.hariAktif, sesudah.hariAktif),
      listener: (context, _) => context.read<RiwayatCubit>().muatGrafik(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return switch (item) {
            _ItemAtas() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Jarak.s8,
                    runSpacing: Jarak.s8,
                    children: [
                      Text('Riwayat', style: judul()),
                      Wrap(
                        spacing: Jarak.s4,
                        runSpacing: Jarak.s4,
                        children: [
                          for (final r in RentangRiwayat.values)
                            _PilRentang(
                              label: r.label,
                              aktif: riwayatState.rentang == r,
                              onTap: () => riwayatCubit.pilihRentang(r),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: Jarak.s12),
                  _SegmenNutrisi(
                    zatDipilih: _zat,
                    onPilih: (zat) => setState(() => _zat = zat),
                  ),
                  const SizedBox(height: Jarak.s16),
                  KartuPutih(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (riwayatState.rentang == RentangRiwayat.tujuhHari)
                          Row(
                            children: [
                              IconButton(
                                onPressed: riwayatState.memuat ? null : riwayatCubit.mingguSebelumnya,
                                tooltip: 'Minggu sebelumnya',
                                icon: const Icon(Icons.chevron_left_rounded, color: Warna.tinta),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      rentangMinggu(riwayatState.awalRentang),
                                      style: teksLabel(bobot: FontWeight.w800),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: Jarak.s4),
                                    Text(
                                      'Rata-rata ${angka(rataRata)} $satuan · $statusRingkasan',
                                      style: teksKecil(bobot: FontWeight.w700),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: (!riwayatState.memuat && riwayatState.bisaKeMingguBerikutnya)
                                    ? riwayatCubit.mingguBerikutnya
                                    : null,
                                tooltip: 'Minggu berikutnya',
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: riwayatState.bisaKeMingguBerikutnya ? Warna.tinta : Warna.garis,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${riwayatState.rentang.jumlahHari} hari terakhir', style: teksBadan(bobot: FontWeight.w800)),
                              const SizedBox(height: Jarak.s4),
                              Text(
                                'Rata-rata ${angka(rataRata)} $satuan · $statusRingkasan',
                                style: teksLabel(warna: Warna.tintaLembut),
                              ),
                            ],
                          ),
                        const SizedBox(height: Jarak.s8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(width: Jarak.s16, child: _GarisPutus()),
                            const SizedBox(width: Jarak.s4),
                            Text('Batas ${angka(batas)} $satuan', style: teksKecil(bobot: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: Jarak.s8),
                        _Grafik(
                          hari: daftarHari,
                          nilai: nilai,
                          batas: batas,
                          satuan: satuan,
                          hariIni: hariIni,
                          rentang: riwayatState.rentang,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Jarak.s16),
                  if (kelompok.isEmpty && kelompokSesi.isEmpty && !state.memuat)
                    Padding(
                      padding: const EdgeInsets.only(top: Jarak.s12, bottom: Jarak.s8),
                      child: Text(
                        'Belum ada catatan. Pindai label pertamamu dari Beranda.',
                        style: teksBadan(warna: Warna.tintaLembut),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            _ItemHeaderTanggal(:final judulTanggal, :final nilaiHariIni) => Padding(
                padding: const EdgeInsets.only(top: Jarak.s8, bottom: Jarak.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        judulTanggal,
                        style: teksLabel(bobot: FontWeight.w800, warna: Warna.tintaLembut),
                      ),
                    ),
                    if (nilaiHariIni != null)
                      Text(nilaiHariIni, style: teksLabel(bobot: FontWeight.w800)),
                  ],
                ),
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
            _ItemSesiOlahraga(:final sesi) => _KartuSesiOlahraga(sesi: sesi),
            _ItemMemuat() => const Padding(
                padding: EdgeInsets.symmetric(vertical: Jarak.s16),
                child: Center(child: CircularProgressIndicator(color: Warna.hijauTua)),
              ),
          };
        },
      ),
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
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LembarDetailKonsumsi(baris: baris),
    );
  }
}

class _KartuSesiOlahraga extends StatelessWidget {
  const _KartuSesiOlahraga({required this.sesi});

  final SesiOlahraga sesi;

  static IconData _ikon(JenisOlahraga j) => switch (j) {
        JenisOlahraga.jalan => Icons.directions_walk_rounded,
        JenisOlahraga.jogging || JenisOlahraga.lari => Icons.directions_run_rounded,
        JenisOlahraga.lainnya => Icons.fitness_center_rounded,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Jarak.s8),
        child: KartuPutih(
          padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Warna.permukaanRedup,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_ikon(sesi.jenis), size: 22, color: Warna.tinta),
              ),
              const SizedBox(width: Jarak.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sesi.teksRingkasan, style: teksBadan(bobot: FontWeight.w800)),
                    const SizedBox(height: Jarak.s4),
                    Text(jam(sesi.mulai), style: teksKecil()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PilRentang extends StatelessWidget {
  const _PilRentang({required this.label, required this.aktif, required this.onTap});
  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: aktif,
        child: Material(
          color: aktif ? Warna.tinta : Warna.kartu,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: aktif ? BorderSide.none : const BorderSide(color: Warna.garis, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s8),
              child: Text(
                label,
                style: teksKecil(
                  bobot: FontWeight.w800,
                  warna: aktif ? Warna.kartu : Warna.tintaLembut,
                ),
              ),
            ),
          ),
        ),
      );
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

class _LembarDetailKonsumsi extends StatefulWidget {
  const _LembarDetailKonsumsi({required this.baris});
  final BarisRiwayat baris;

  @override
  State<_LembarDetailKonsumsi> createState() => _LembarDetailKonsumsiState();
}

class _LembarDetailKonsumsiState extends State<_LembarDetailKonsumsi> {
  late BarisRiwayat _baris = widget.baris;
  bool _proses = false;
  bool _sedangCatatLagi = false;

  static String _persenTeks(double? nilai, double batas) {
    final p = persenJatah(nilai, batas);
    return p == null ? 'Tidak ada data' : '${(p * 100).round()}% jatah harian';
  }

  Future<void> _ubahPorsi() async {
    if (_proses) return;
    final porsiBaru = await tampilkanDialogPorsi(
      context,
      judulDialog: 'Ubah porsi',
      porsiAwal: _baris.jumlahSajian,
      labelSimpan: 'Simpan',
    );
    if (porsiBaru == null || !mounted) return;
    setState(() => _proses = true);
    final cubit = context.read<AsupanCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final terbaru = await cubit.ubahPorsi(_baris.id, porsiBaru);
    if (!mounted) return;
    setState(() {
      _proses = false;
      if (terbaru != null) _baris = terbaru;
    });
    if (terbaru != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Porsi diperbarui')));
    }
  }

  Future<void> _bagikan() async {
    if (_proses) return;
    setState(() => _proses = true);
    try {
      final batas = context.read<ProfilCubit>().state.batas;
      await tampilkanLembarBagikan(context, DataKartuBagikan.dariRiwayat(_baris, batas: batas));
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _hapus() async {
    if (_proses) return;
    setState(() => _proses = true);
    final cubit = context.read<AsupanCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final terhapus = await cubit.hapus(_baris);
    if (!mounted) return;
    if (terhapus == null) {
      setState(() => _proses = false);
      return;
    }
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${terhapus.nama} dihapus'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Urungkan', onPressed: () => cubit.kembalikan(terhapus)),
      ));
  }

  Future<void> _catatLagi() async {
    if (_proses) return;
    setState(() {
      _proses = true;
      _sedangCatatLagi = true;
    });
    final cubit = context.read<AsupanCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await cubit.catatLagi(_baris);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _proses = false;
        _sedangCatatLagi = false;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Gagal mencatat ulang produk.')));
      return;
    }
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${_baris.nama} dicatat lagi untuk hari ini')));
  }

  @override
  Widget build(BuildContext context) {
    final batas = context.watch<ProfilCubit>().state.batas;
    final padanan = [
      if (_baris.gulaG != null) 'setara ${teksSendok(sendokGula(_baris.gulaG!))} sdm gula',
      if (_baris.natriumMg != null) 'setara ${teksSendok(sendokGaram(_baris.natriumMg!))} sdt garam',
      if (_baris.lemakTotalG != null) 'setara ${teksSendok(sendokMinyak(_baris.lemakTotalG!))} sdm minyak',
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
              Expanded(child: Text(_baris.nama, style: judulKecil(tinggi: 1.2))),
              IconButton(
                onPressed: _proses ? null : () => Navigator.pop(context),
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
                '${tanggalPendek(_baris.waktu)}, ${jam(_baris.waktu)} · ${_baris.jumlahSajian == 0.5 ? '½' : angka(_baris.jumlahSajian)} sajian',
                style: teksLabel(bobot: FontWeight.w600, warna: Warna.tintaLembut),
              ),
              ChipStatus(_baris.statusUntuk(batas)),
            ],
          ),
          const SizedBox(height: Jarak.s16),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _PetakNilai(
                  nama: 'Gula',
                  isi: _baris.gulaG == null ? '-' : '${angka(_baris.gulaG!)} g',
                  persen: _persenTeks(_baris.gulaG, batas.gulaG),
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: _PetakNilai(
                  nama: 'Natrium',
                  isi: _baris.natriumMg == null ? '-' : '${angka(_baris.natriumMg!)} mg',
                  persen: _persenTeks(_baris.natriumMg, batas.natriumMg),
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: _PetakNilai(
                  nama: 'Lemak',
                  isi: _baris.lemakTotalG == null ? '-' : '${angka(_baris.lemakTotalG!)} g',
                  persen: _persenTeks(_baris.lemakTotalG, batas.lemakG),
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
          const SizedBox(height: Jarak.s16),
          Row(
            children: [
              Expanded(
                child: _TombolAksiDetail(
                  label: 'Ubah porsi',
                  ikon: Icons.edit_outlined,
                  onPressed: _proses ? null : _ubahPorsi,
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: _TombolAksiDetail(
                  label: 'Bagikan',
                  ikon: Icons.share_outlined,
                  onPressed: _proses ? null : _bagikan,
                ),
              ),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: _TombolAksiDetail(
                  label: 'Hapus',
                  ikon: Icons.delete_outline_rounded,
                  bahaya: true,
                  onPressed: _proses ? null : _hapus,
                ),
              ),
            ],
          ),
          const SizedBox(height: Jarak.s12),
          TombolTebal(
            label: _sedangCatatLagi ? 'Mencatat...' : 'Catat lagi sekarang',
            memuat: _sedangCatatLagi,
            onPressed: _proses ? null : _catatLagi,
          ),
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

class _TombolAksiDetail extends StatelessWidget {
  const _TombolAksiDetail({
    required this.label,
    required this.ikon,
    required this.onPressed,
    this.bahaya = false,
  });

  final String label;
  final IconData ikon;
  final VoidCallback? onPressed;
  final bool bahaya;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    final latar = !aktif ? Warna.jalurBilah : (bahaya ? Warna.bahayaLatar : Warna.kartu);
    final tepi = !aktif ? Warna.garis : (bahaya ? Warna.bahayaGaris : Warna.garis);
    final warnaTeks = !aktif ? Warna.tintaLembut : (bahaya ? Warna.tinggiChip : Warna.tinta);
    return Semantics(
      button: true,
      enabled: aktif,
      child: Material(
        color: latar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tepi, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tepi, width: 3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ikon, size: 20, color: warnaTeks),
                const SizedBox(height: Jarak.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: teksKecil(bobot: FontWeight.w800, warna: warnaTeks),
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

class _PetakNilai extends StatelessWidget {
  const _PetakNilai({required this.nama, required this.isi, required this.persen});
  final String nama;
  final String isi;
  final String persen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Jarak.s8),
        decoration: BoxDecoration(
          color: Warna.kartu,
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
  const _Grafik({
    required this.hari,
    required this.nilai,
    required this.batas,
    required this.satuan,
    required this.hariIni,
    required this.rentang,
  });

  final List<DateTime> hari;
  final List<double> nilai;
  final double batas;
  final String satuan;
  final DateTime hariIni;
  final RentangRiwayat rentang;

  static const _tinggi = 150.0;

  static Color _warnaBatang(double v, double batas) => switch (statusHarian(v, batas)) {
        StatusHarian.aman => Warna.aman,
        StatusHarian.hampirBatas => Warna.waspada,
        StatusHarian.lewatBatas => Warna.tinggi,
      };

  @override
  Widget build(BuildContext context) {
    final puncak = [batas * 1.4, ...nilai].reduce((a, b) => a > b ? a : b);
    final yBatas = batas / puncak * _tinggi;
    final tujuhHari = rentang == RentangRiwayat.tujuhHari;
    final jarakSamping = switch (rentang) {
      RentangRiwayat.tujuhHari => Jarak.s4,
      RentangRiwayat.tigaPuluhHari => 1.0,
      RentangRiwayat.sembilanPuluhHari => 0.5,
    };
    final radiusBatang = switch (rentang) {
      RentangRiwayat.tujuhHari => const BorderRadius.vertical(
          top: Radius.circular(Jarak.s8),
          bottom: Radius.circular(Jarak.s4),
        ),
      RentangRiwayat.tigaPuluhHari => const BorderRadius.vertical(top: Radius.circular(3)),
      RentangRiwayat.sembilanPuluhHari => const BorderRadius.vertical(top: Radius.circular(1)),
    };

    return Semantics(
      label: 'Grafik ${rentang.label}, batas ${angka(batas)} $satuan',
      child: Column(children: [
        Container(
          height: _tinggi + (tujuhHari ? 36 : 16),
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
                      padding: EdgeInsets.symmetric(horizontal: jarakSamping),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (tujuhHari && v > 0 && (hariSama(hari[i], hariIni) || v > batas)) ...[
                          FittedBox(
                            child: Text(
                              '${angka(v)} $satuan',
                              style: teksKecil(
                                bobot: FontWeight.w800,
                                warna: v > batas ? Warna.tinggiChip : Warna.tinta,
                              ),
                            ),
                          ),
                          const SizedBox(height: Jarak.s4),
                        ],
                        if (v <= 0)
                          Container(
                            width: tujuhHari ? Jarak.s8 : Jarak.s4,
                            height: tujuhHari ? Jarak.s8 : 3,
                            margin: EdgeInsets.only(bottom: tujuhHari ? Jarak.s4 : 1),
                            decoration: BoxDecoration(
                              color: Warna.jalurBilah,
                              borderRadius: BorderRadius.circular(Jarak.s4),
                            ),
                          )
                        else
                          Container(
                            height: (v / puncak * _tinggi).clamp(Jarak.s4, _tinggi),
                            decoration: BoxDecoration(
                              color: _warnaBatang(v, batas),
                              borderRadius: radiusBatang,
                              border: (tujuhHari && hariSama(hari[i], hariIni))
                                  ? Border.all(color: Warna.tinta, width: 2)
                                  : null,
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
        if (tujuhHari)
          Row(children: [
            for (final h in hari)
              Expanded(
                child: Text(
                  hariSingkat(h),
                  textAlign: TextAlign.center,
                  style: teksKecil(
                    bobot: hariSama(h, hariIni) ? FontWeight.w800 : FontWeight.w700,
                    warna: hariSama(h, hariIni) ? Warna.tinta : Warna.tintaLembut,
                  ),
                ),
              ),
          ])
        else if (hari.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tanggalSingkat(hari.first), style: teksKecil(bobot: FontWeight.w700)),
              Text('Hari ini', style: teksKecil(bobot: FontWeight.w800, warna: Warna.tinta)),
            ],
          ),
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
