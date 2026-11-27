import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/aktivitas/presentation/izin_aktivitas_page.dart';
import '../features/asupan/asupan_cubit.dart';
import '../features/asupan/beranda_page.dart';
import '../features/asupan/cek_hasil_page.dart';
import '../features/bandingkan/presentation/bandingkan_page.dart';
import '../features/langganan/langganan_page.dart';
import '../features/perkenalan/perkenalan_page.dart';
import '../features/pindai/kontrak_ocr.dart';
import '../features/pindai/membaca_label_page.dart';
import '../features/pindai/pindai_gagal_page.dart';
import '../features/produk/produk_saya_page.dart';
import '../features/profil/presentation/profil_batas_page.dart';
import '../features/profil/profil_page.dart';
import '../features/rapor/rapor_page.dart';
import '../features/riwayat/riwayat_page.dart';
import '../features/tantangan/presentation/tantangan_page.dart';
import '../features/tentang/tentang_page.dart';
import '../main.dart';
import 'theme/tema.dart';
import 'theme/warna.dart';

final RouteObserver<ModalRoute<void>> pengamatRute = RouteObserver<ModalRoute<void>>();

GoRouter buatRouter({String awal = '/perkenalan', ValueNotifier<bool>? pemicuBarcode}) => GoRouter(
      initialLocation: awal,
      observers: [pengamatRute],
      redirect: (_, s) => s.error != null ? '/beranda' : null,
      errorBuilder: (c, _) => batasiLebarIsi(c, BerandaPage(pemicuBarcode: pemicuBarcode)),
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, _) => '/beranda',
        ),
        GoRoute(
          path: '/perkenalan',
          builder: (c, _) => batasiLebarIsi(c, const PerkenalanPage()),
        ),
        GoRoute(
          path: '/pindai',
          builder: (c, s) => batasiLebarIsi(
            c,
            MembacaLabelPage(barcode: s.extra is String ? s.extra as String : null),
          ),
        ),
        GoRoute(
          path: '/cek',
          builder: (c, s) => batasiLebarIsi(
            c,
            CekHasilPage(draf: s.extra as DrafProduk? ?? DrafProduk.kosong),
          ),
        ),
        GoRoute(
          path: '/tidak-terbaca',
          builder: (c, s) {
            final extra = s.extra;
            final GalatPindai? galat = extra is GalatPindai
                ? extra
                : (extra is ({GalatPindai galat, String? barcode}) ? extra.galat : null);
            final String? barcode = extra is ({GalatPindai galat, String? barcode}) ? extra.barcode : null;
            return batasiLebarIsi(c, PindaiGagalPage.tidakTerbaca(galat: galat, barcode: barcode));
          },
        ),
        GoRoute(
          path: '/kuota-habis',
          builder: (c, s) => batasiLebarIsi(
            c,
            PindaiGagalPage.kuotaHabis(barcode: s.extra is String ? s.extra as String : null),
          ),
        ),
        GoRoute(
          path: '/langganan',
          builder: (c, _) => batasiLebarIsi(c, const LanggananPage()),
        ),
        GoRoute(
          path: '/tentang',
          builder: (c, _) => batasiLebarIsi(c, const TentangPage()),
        ),
        GoRoute(
          path: '/produk',
          builder: (c, _) => batasiLebarIsi(c, const ProdukSayaPage()),
        ),
        GoRoute(
          path: '/bandingkan',
          builder: (c, s) {
            final extra = s.extra;
            ProdukRingkas? awalA;
            ProdukRingkas? awalB;
            if (extra is List<ProdukRingkas> && extra.length >= 2) {
              awalA = extra[0];
              awalB = extra[1];
            }
            return batasiLebarIsi(c, BandingkanPage(awalA: awalA, awalB: awalB));
          },
        ),
        GoRoute(
          path: '/tantangan',
          builder: (c, _) => batasiLebarIsi(c, const TantanganPage()),
        ),
        GoRoute(
          path: '/aktivitas/izin',
          builder: (c, _) => batasiLebarIsi(c, const IzinAktivitasPage()),
        ),
        GoRoute(
          path: '/profil/batas',
          builder: (c, s) => batasiLebarIsi(
            c,
            ProfilBatasPage(
              awal: s.uri.queryParameters['awal'] == '1',
              tambah: s.uri.queryParameters['tambah'] == '1',
            ),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => _Kerangka(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/beranda', builder: (_, _) => BerandaPage(pemicuBarcode: pemicuBarcode)),
              ],
            ),
            StatefulShellBranch(routes: [GoRoute(path: '/riwayat', builder: (_, _) => const RiwayatPage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/rapor', builder: (_, _) => const RaporPage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/profil', builder: (_, _) => const ProfilPage())]),
          ],
        ),
      ],
    );

class _Kerangka extends StatelessWidget {
  const _Kerangka({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(bottom: false, child: batasiLebarIsi(context, shell)),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Warna.kartu,
            indicatorColor: Warna.permukaanRedup,
            height: 80,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => teksKecil(
                bobot: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                warna: s.contains(WidgetState.selected) ? Warna.hijauTua : Warna.tintaLembut,
              ),
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
                NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded), label: 'Rapor'),
                NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
              ],
            ),
          ),
        ),
      );
}
