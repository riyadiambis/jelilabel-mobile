import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ambang.dart';
import '../../../core/di/injeksi.dart';
import '../../../core/theme/tema.dart';
import '../../../core/theme/warna.dart';
import '../../../core/widgets/komponen.dart';
import '../../asupan/asupan_cubit.dart';
import '../../asupan/data/asupan_repository.dart';
import '../domain/pemindai_barcode.dart';

enum AksiBarcodeBaru { fotoLabel, isiManual }

/// Menjalankan alur pindai barcode dari Beranda:
/// - Ditemukan: lembar F7 + dialog porsi, tanpa memakai kuota pindai.
/// - Tidak ditemukan: lembar F7 produk baru (Foto label gizi / Isi manual), membawa barcode ke draf.
/// - Batal: kembali tanpa pesan galat.
/// - Modul tidak tersedia: snackbar informasi.
Future<void> jalankanAlurBarcode(BuildContext context) async {
  final pemindai = getIt<PemindaiBarcode>();
  final repo = getIt<AsupanRepository>();
  final asupanCubit = context.read<AsupanCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final hasil = await pemindai.pindai();
  if (!context.mounted) return;

  switch (hasil.status) {
    case StatusPindaiBarcode.batal:
      return;
    case StatusPindaiBarcode.tidakTersedia:
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Pemindai barcode belum tersedia di HP ini.')),
        );
      return;
    case StatusPindaiBarcode.berhasil:
      final kode = hasil.kode!;
      final produk = await repo.cariProdukByBarcode(kode);
      if (!context.mounted) return;

      if (produk != null) {
        final porsi = await tampilkanLembarBarcodeDitemukan(context, produk);
        if (porsi == null || !context.mounted) return;
        final ok = await asupanCubit.catatProduk(produk.id, porsi);
        if (!context.mounted) return;
        if (!ok) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(asupanCubit.state.galat ?? 'Gagal mencatat produk.')),
            );
          return;
        }
        await tampilkanLembarTercatat(context);
        return;
      }

      final aksi = await tampilkanLembarBarcodeBaru(context);
      if (aksi == null || !context.mounted) return;
      switch (aksi) {
        case AksiBarcodeBaru.fotoLabel:
          final rute = asupanCubit.state.sisaKuota == 0 ? '/kuota-habis' : '/pindai';
          await router.push(rute, extra: kode);
        case AksiBarcodeBaru.isiManual:
          await router.push('/cek', extra: DrafProduk(nama: '', barcode: kode));
      }
  }
}

/// Lembar F7 saat barcode ditemukan di Produk saya. Mengembalikan porsi terpilih atau null.
Future<double?> tampilkanLembarBarcodeDitemukan(BuildContext context, ProdukRingkas produk) =>
    showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LembarBarcodeDitemukan(produk: produk),
    );

/// Lembar F7 saat barcode belum ada di Produk saya.
Future<AksiBarcodeBaru?> tampilkanLembarBarcodeBaru(BuildContext context) => showModalBottomSheet<AksiBarcodeBaru>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Jarak.s20, Jarak.s12, Jarak.s20, Jarak.s24),
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
              const SizedBox(height: Jarak.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Maskot('04-bingung', ukuran: 72, label: 'Nuri bingung'),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Produk baru buat Nuri', style: judulKecil()),
                        const SizedBox(height: Jarak.s4),
                        Text(
                          'Foto labelnya sekali. Lain kali cukup barcode, tanpa kuota.',
                          style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Jarak.s16),
              TombolTebal.pindai(
                label: 'Foto label gizi',
                onPressed: () => Navigator.of(c).pop(AksiBarcodeBaru.fotoLabel),
              ),
              const SizedBox(height: Jarak.s12),
              TombolTebal.sekunder(
                label: 'Isi manual',
                onPressed: () => Navigator.of(c).pop(AksiBarcodeBaru.isiManual),
              ),
            ],
          ),
        ),
      ),
    );

class _LembarBarcodeDitemukan extends StatefulWidget {
  const _LembarBarcodeDitemukan({required this.produk});
  final ProdukRingkas produk;

  @override
  State<_LembarBarcodeDitemukan> createState() => _LembarBarcodeDitemukanState();
}

class _LembarBarcodeDitemukanState extends State<_LembarBarcodeDitemukan> {
  bool _memilihPorsi = false;

  static String _nilai(double? v) => v == null ? '-' : angka(v);

  Future<void> _pilihPorsi() async {
    if (_memilihPorsi) return;
    setState(() => _memilihPorsi = true);
    try {
      final porsi = await tampilkanDialogPorsi(
        context,
        judulDialog: 'Catat ${widget.produk.nama}',
        porsiAwal: 1,
        labelSimpan: 'Catat',
      );
      if (porsi != null && mounted) {
        Navigator.of(context).pop(porsi);
      }
    } finally {
      if (mounted) setState(() => _memilihPorsi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produk;
    final takaran = p.takaranJumlah == null ? null : '${angka(p.takaranJumlah!)} ${p.takaranSatuan ?? 'g'}';
    final gizi = '${_nilai(p.gulaG)} g gula · ${_nilai(p.natriumMg)} mg natrium · ${_nilai(p.lemakTotalG)} g lemak per sajian';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Jarak.s20, Jarak.s12, Jarak.s20, Jarak.s24),
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
            const SizedBox(height: Jarak.s12),
            Text(
              'DITEMUKAN DI PRODUK SAYA',
              style: teksKecil(bobot: FontWeight.w800, warna: Warna.tintaLembut),
            ),
            const SizedBox(height: Jarak.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(p.nama, style: judulKecil())),
                if (takaran != null) ...[
                  const SizedBox(width: Jarak.s8),
                  Text(takaran, style: teksLabel(warna: Warna.tintaLembut)),
                ],
              ],
            ),
            const SizedBox(height: Jarak.s8),
            Text(gizi, style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.4)),
            const SizedBox(height: Jarak.s16),
            TombolTebal(
              label: 'Catat 1 porsi',
              onPressed: _memilihPorsi ? null : _pilihPorsi,
            ),
          ],
        ),
      ),
    );
  }
}
