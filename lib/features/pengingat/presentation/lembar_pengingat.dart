import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/tema.dart';
import '../../../core/theme/warna.dart';
import '../domain/pengaturan_pengingat.dart';
import 'pengingat_cubit.dart';

/// Lembar pengaturan pengingat harian di menu Profil > Pengingat (F-16).
Future<void> tampilkanLembarPengingat(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Warna.kartu,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BlocProvider.value(
        value: context.read<PengingatCubit>(),
        child: const _LembarPengingat(),
      ),
    );

class _LembarPengingat extends StatefulWidget {
  const _LembarPengingat();

  @override
  State<_LembarPengingat> createState() => _LembarPengingatState();
}

class _LembarPengingatState extends State<_LembarPengingat> {
  Future<void> _ubahSakelar(bool aktifBaru) async {
    final cubit = context.read<PengingatCubit>();
    await cubit.ubahAktif(aktifBaru);
  }

  Future<void> _pilihJam(PengingatState state) async {
    if (state.memproses) return;
    final cubit = context.read<PengingatCubit>();
    final terpilih = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.pengaturan.jam, minute: state.pengaturan.menit),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (terpilih == null || !mounted) return;
    await cubit.ubahJam(terpilih.hour, terpilih.minute);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PengingatCubit>().state;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Jarak.layar, Jarak.s16, Jarak.layar, Jarak.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Pengingat harian', style: judulKecil())),
                IconButton(
                  onPressed: state.memproses ? null : () => Navigator.pop(context),
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded, color: Warna.tintaLembut),
                ),
              ],
            ),
            Text(
              'Nuri mengingatkan sekali sehari bila hari itu belum ada catatan.',
              style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.45),
            ),
            const SizedBox(height: Jarak.s16),
            Container(
              decoration: BoxDecoration(
                color: Warna.latar,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Warna.garis),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Aktifkan pengingat',
                              style: teksBadan(bobot: FontWeight.w700),
                            ),
                          ),
                          Switch(
                            value: state.aktif,
                            onChanged: state.memproses ? null : _ubahSakelar,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Warna.garis),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: state.memproses ? null : () => _pilihJam(state),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded, color: Warna.tinta),
                              const SizedBox(width: Jarak.s12),
                              Expanded(
                                child: Text('Jam pengingat', style: teksBadan(bobot: FontWeight.w700)),
                              ),
                              Text(
                                state.jamTeks,
                                style: teksBadan(bobot: FontWeight.w800, warna: Warna.hijauTua),
                              ),
                              const SizedBox(width: Jarak.s4),
                              const Icon(Icons.chevron_right_rounded, color: Warna.tintaLembut),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.izinDitolak) ...[
              const SizedBox(height: Jarak.s12),
              Container(
                padding: const EdgeInsets.all(Jarak.s12),
                decoration: BoxDecoration(
                  color: Warna.oranyeMuda,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Warna.oranye),
                ),
                child: Text(
                  'Izin notifikasi ditolak. Bisa diubah di Pengaturan HP.',
                  style: teksLabel(bobot: FontWeight.w700, warna: Warna.oranyeTeks, tinggi: 1.4),
                ),
              ),
            ],
            if (state.galat != null) ...[
              const SizedBox(height: Jarak.s12),
              Text(
                state.galat!,
                style: teksLabel(bobot: FontWeight.w700, warna: Warna.oranyeTeks),
              ),
            ],
            const SizedBox(height: Jarak.s16),
            Container(
              padding: const EdgeInsets.all(Jarak.s12),
              decoration: BoxDecoration(
                color: Warna.permukaanRedup,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 18, color: Warna.tintaLembut),
                  const SizedBox(width: Jarak.s8),
                  Expanded(
                    child: Text(
                      '"$teksPengingatHarian"',
                      style: teksLabel(warna: Warna.tintaLembut, tinggi: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
