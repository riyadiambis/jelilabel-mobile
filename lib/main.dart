import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injeksi.dart';
import 'core/router.dart';
import 'core/theme/tema.dart';
import 'core/theme/warna.dart';
import 'core/widgets/komponen.dart';
import 'features/asupan/asupan_cubit.dart';
import 'features/asupan/data/asupan_repository.dart';

const lebarMaksIsi = 600.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _mulai();
}

Future<void> _mulai() async {
  try {
    await siapkanDependensi();
    final sudahPerkenalan = await getIt<AsupanRepository>().perkenalanSelesai();
    runApp(JeliLabelApp(awal: sudahPerkenalan ? '/beranda' : '/perkenalan'));
  } catch (_) {
    runApp(const _GagalMulai());
  }
}

// Tablet (ISSUE-02): isi selebar ponsel di tengah, sisanya latar.
Widget _batasiLebar(BuildContext _, Widget? isi) => ColoredBox(
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
          builder: _batasiLebar,
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
        builder: _batasiLebar,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Maskot('04-bingung', ukuran: 160, label: 'Nuri bingung'),
                    const SizedBox(height: 16),
                    Text('Penyimpanan HP bermasalah', style: fredoka(22), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Memori HP mungkin penuh atau data rusak. Kosongkan sedikit ruang lalu coba lagi.',
                      style: nunito(15, FontWeight.w400, warna: Warna.tintaLembut, tinggi: 1.55),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TombolTebal(label: 'Coba lagi', onPressed: _sedangMencoba ? null : _cobaLagi),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
