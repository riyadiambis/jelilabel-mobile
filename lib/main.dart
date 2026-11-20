import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme/tema.dart';
import 'features/asupan/asupan_cubit.dart';

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
        ),
      );
}
