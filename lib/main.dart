import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme/tema.dart';
import 'core/theme/warna.dart';
import 'features/asupan/asupan_cubit.dart';

const lebarMaksIsi = 600.0;

void main() => runApp(JeliLabelApp());

class JeliLabelApp extends StatelessWidget {
  JeliLabelApp({super.key, String awal = '/perkenalan'}) : _router = buatRouter(awal: awal);

  final GoRouter _router;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AsupanCubit(),
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
