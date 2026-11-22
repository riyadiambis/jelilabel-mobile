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
import 'features/asupan/asupan_cubit.dart';
import 'features/asupan/data/asupan_repository.dart';
import 'features/pindai/layanan_iklan_admob.dart';
import 'features/pindai/pemindai_label_ai_logic.dart';
import 'features/pindai/pemindai_label_firebase.dart';

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
  })  : _router = buatRouter(awal: awal),
        _buatCubit = buatCubit ?? (() => getIt<AsupanCubit>()..muat());

  final GoRouter _router;
  final AsupanCubit Function() _buatCubit;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => _buatCubit(),
        child: MaterialApp.router(
          title: 'JeliLabel',
          debugShowCheckedModeBanner: false,
          theme: temaJeliLabel(),
          routerConfig: _router,
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
