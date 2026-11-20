import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injeksi.dart';
import 'core/router.dart';
import 'core/theme/tema.dart';
import 'core/theme/warna.dart';
import 'features/asupan/asupan_cubit.dart';
import 'features/asupan/data/asupan_repository.dart';

const lebarMaksIsi = 600.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await siapkanDependensi();
  final sudahPerkenalan = await getIt<AsupanRepository>().perkenalanSelesai();
  runApp(JeliLabelApp(awal: sudahPerkenalan ? '/beranda' : '/perkenalan'));
}

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
          // Tablet (ISSUE-02): isi selebar ponsel di tengah, sisanya latar.
          builder: (_, isi) => ColoredBox(
            color: Warna.latar,
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: lebarMaksIsi), child: isi),
            ),
          ),
        ),
      );
}
