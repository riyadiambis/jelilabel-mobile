import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/di/injeksi.dart';
import 'core/router.dart';
import 'core/theme/tema.dart';
import 'core/theme/warna.dart';
import 'core/widgets/komponen.dart';
import 'features/aktivitas/presentation/aktivitas_cubit.dart';
import 'features/asupan/asupan_cubit.dart';
import 'features/asupan/data/asupan_repository.dart';
import 'features/pindai/layanan_iklan_admob.dart';
import 'features/pindai/pemindai_label_ai_logic.dart';
import 'features/pindai/pemindai_label_firebase.dart';
import 'features/profil/presentation/profil_cubit.dart';
import 'features/tantangan/presentation/tantangan_cubit.dart';

const lebarMaksIsi = 600.0;
const bool _modeSimulasi = bool.fromEnvironment('MODE_SIMULASI', defaultValue: false);
const bool _pindaiLewatFunctions = bool.fromEnvironment('PINDAI_LEWAT_FUNCTIONS', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _mulai();
}

Future<void> _mulai() async {
  try {
    var pakaiNative = false;
    if (!_modeSimulasi) {
      try {
        await Firebase.initializeApp();
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
        );
        await MobileAds.instance.initialize();
        pakaiNative = Firebase.apps.isNotEmpty;
      } catch (_) {
        if (kReleaseMode) rethrow;
      }
    }

    await siapkanDependensi(
      pemindaiLabel: pakaiNative
          ? (_pindaiLewatFunctions ? PemindaiLabelFirebase() : PemindaiLabelAiLogic())
          : null,
      layananIklan: pakaiNative ? LayananIklanAdMob(pakaiSsv: _pindaiLewatFunctions) : null,
      hapusDataServer: pakaiNative && _pindaiLewatFunctions ? hapusDataServer : null,
    );
    final sudahPerkenalan = await getIt<AsupanRepository>().perkenalanSelesai();
    runApp(JeliLabelApp(awal: sudahPerkenalan ? '/beranda' : '/perkenalan'));
  } catch (_) {
    runApp(const _GagalMulai());
  }
}

// Tablet (ISSUE-02, ISSUE-12 B14): isi dibatasi maks 600 dp di tengah, latar penuh.
Widget batasiLebarIsi(BuildContext _, Widget? isi) => ColoredBox(
      color: Warna.latar,
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: lebarMaksIsi), child: isi),
      ),
    );

class JeliLabelApp extends StatelessWidget {
  JeliLabelApp({
    super.key,
    String awal = '/perkenalan',
    AsupanCubit Function()? buatCubit,
    ProfilCubit Function()? buatProfilCubit,
    TantanganCubit Function()? buatTantanganCubit,
    AktivitasCubit Function()? buatAktivitasCubit,
  })  : _router = buatRouter(awal: awal),
        _buatCubit = buatCubit ?? (() => getIt<AsupanCubit>()..muat()),
        _buatProfilCubit = buatProfilCubit ?? (() => getIt<ProfilCubit>()..muat()),
        _buatTantanganCubit = buatTantanganCubit ?? (() => getIt<TantanganCubit>()..muat()),
        _buatAktivitasCubit = buatAktivitasCubit ?? (() => getIt<AktivitasCubit>()..muat());

  final GoRouter _router;
  final AsupanCubit Function() _buatCubit;
  final ProfilCubit Function() _buatProfilCubit;
  final TantanganCubit Function() _buatTantanganCubit;
  final AktivitasCubit Function() _buatAktivitasCubit;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => _buatCubit()),
          BlocProvider(create: (_) => _buatProfilCubit()),
          BlocProvider(create: (_) => _buatTantanganCubit()),
          BlocProvider(create: (_) => _buatAktivitasCubit()),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<AsupanCubit, AsupanState>(
              listenWhen: (sebelum, sesudah) =>
                  sebelum.daftar != sesudah.daftar ||
                  sebelum.ringkasan != sesudah.ringkasan ||
                  !hariSama(sebelum.hariAktif, sesudah.hariAktif),
              listener: (context, sesudah) {
                context.read<TantanganCubit>().muat();
                if (sesudah.daftar.isNotEmpty && context.read<ProfilCubit>().state.daftarProfil.isEmpty) {
                  context.read<ProfilCubit>().muat();
                }
              },
            ),
            BlocListener<ProfilCubit, ProfilState>(
              listenWhen: (sebelum, sesudah) =>
                  (sebelum.sudahMuat && sebelum.profil.id != sesudah.profil.id) ||
                  sebelum.batas != sesudah.batas,
              listener: (context, _) {
                context.read<AsupanCubit>().muat();
                context.read<TantanganCubit>().muat();
              },
            ),
          ],
          child: MaterialApp.router(
            title: 'JeliLabel',
            debugShowCheckedModeBanner: false,
            theme: temaJeliLabel(),
            routerConfig: _router,
          ),
        ),
      );
}

class _GagalMulai extends StatefulWidget {
  const _GagalMulai();

  @override
  State<_GagalMulai> createState() => _GagalMulaiState();
}

class _GagalMulaiState extends State<_GagalMulai> {
  bool _sedangMencoba = false;

  Future<void> _cobaLagi() async {
    if (_sedangMencoba) return;
    setState(() => _sedangMencoba = true);
    await _mulai();
    if (mounted) setState(() => _sedangMencoba = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'JeliLabel',
        debugShowCheckedModeBanner: false,
        theme: temaJeliLabel(),
        builder: batasiLebarIsi,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Jarak.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Maskot('04-bingung', ukuran: 160, label: 'Nuri bingung'),
                    const SizedBox(height: Jarak.s16),
                    Text('Penyimpanan HP bermasalah', style: judul(), textAlign: TextAlign.center),
                    const SizedBox(height: Jarak.s8),
                    Text(
                      'Memori HP mungkin penuh atau data rusak. Kosongkan sedikit ruang lalu coba lagi.',
                      style: teksBadan(warna: Warna.tintaLembut, tinggi: 1.55),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Jarak.s24),
                    TombolTebal(label: 'Coba lagi', onPressed: _sedangMencoba ? null : _cobaLagi),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
