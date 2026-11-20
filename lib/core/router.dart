import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/asupan/asupan_cubit.dart';
import '../features/asupan/beranda_page.dart';
import '../features/asupan/cek_hasil_page.dart';
import '../features/langganan/langganan_page.dart';
import '../features/perkenalan/perkenalan_page.dart';
import '../features/pindai/membaca_label_page.dart';
import '../features/pindai/pindai_gagal_page.dart';
import '../features/riwayat/riwayat_page.dart';
import '../features/tentang/tentang_page.dart';
import 'theme/tema.dart';
import 'theme/warna.dart';

GoRouter buatRouter({String awal = '/perkenalan'}) => GoRouter(
      initialLocation: awal,
      routes: [
        GoRoute(path: '/perkenalan', builder: (_, _) => const PerkenalanPage()),
        GoRoute(path: '/pindai', builder: (_, _) => const MembacaLabelPage()),
        GoRoute(
          path: '/cek',
          builder: (_, s) => CekHasilPage(draf: s.extra as DrafProduk? ?? DrafProduk.kosong),
        ),
        GoRoute(path: '/tidak-terbaca', builder: (_, _) => const PindaiGagalPage.tidakTerbaca()),
        GoRoute(path: '/kuota-habis', builder: (_, _) => const PindaiGagalPage.kuotaHabis()),
        GoRoute(path: '/langganan', builder: (_, _) => const LanggananPage()),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => _Kerangka(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/beranda', builder: (_, _) => const BerandaPage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/riwayat', builder: (_, _) => const RiwayatPage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/tentang', builder: (_, _) => const TentangPage())]),
          ],
        ),
      ],
    );

class _Kerangka extends StatelessWidget {
  const _Kerangka({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(bottom: false, child: shell),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Warna.kartu,
            indicatorColor: Warna.permukaanRedup,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => nunito(12, s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                  warna: s.contains(WidgetState.selected) ? Warna.hijauTua : Warna.tintaLembut),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Warna.hijauTua : Warna.tintaLembut),
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.garis))),
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Riwayat'),
                NavigationDestination(icon: Icon(Icons.info_outline_rounded), selectedIcon: Icon(Icons.info_rounded), label: 'Tentang'),
              ],
            ),
          ),
        ),
      );
}
