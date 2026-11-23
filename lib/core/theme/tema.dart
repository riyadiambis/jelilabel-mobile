import 'package:flutter/material.dart';

import 'warna.dart';

/// Skala jarak tetap kelipatan 4 (ISSUE-12 A1). Padding sisi layar memakai [Jarak.layar].
abstract final class Jarak {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double layar = s20;
}

/// Gaya teks. Font variabel butuh FontVariation agar bobotnya benar-benar berubah.
TextStyle nunito(double ukuran, FontWeight bobot, {Color warna = Warna.tinta, double? tinggi}) =>
    TextStyle(
      fontFamily: 'Nunito',
      fontSize: ukuran,
      fontWeight: bobot,
      fontVariations: [FontVariation.weight(bobot.value.toDouble())],
      color: warna,
      height: tinggi,
    );

TextStyle fredoka(double ukuran, {Color warna = Warna.tinta, double? tinggi}) => TextStyle(
      fontFamily: 'Fredoka',
      fontSize: ukuran,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation.weight(600)],
      color: warna,
      height: tinggi,
    );

// Skala teks tetap (ISSUE-12 A1): 12, 14, 16 (Nunito) dan 20, 24, 32 (Fredoka).
TextStyle teksKecil({FontWeight bobot = FontWeight.w400, Color warna = Warna.tintaLembut, double? tinggi}) =>
    nunito(12, bobot, warna: warna, tinggi: tinggi);

TextStyle teksLabel({FontWeight bobot = FontWeight.w400, Color warna = Warna.tinta, double? tinggi}) =>
    nunito(14, bobot, warna: warna, tinggi: tinggi);

TextStyle teksBadan({FontWeight bobot = FontWeight.w400, Color warna = Warna.tinta, double? tinggi}) =>
    nunito(16, bobot, warna: warna, tinggi: tinggi);

TextStyle judulKecil({Color warna = Warna.tinta, double? tinggi}) =>
    fredoka(20, warna: warna, tinggi: tinggi);

TextStyle judul({Color warna = Warna.tinta, double? tinggi}) =>
    fredoka(24, warna: warna, tinggi: tinggi);

TextStyle judulBesar({Color warna = Warna.tinta, double? tinggi}) =>
    fredoka(32, warna: warna, tinggi: tinggi);

ThemeData temaJeliLabel() {
  final dasar = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Warna.latar,
    colorScheme: const ColorScheme.light(
      primary: Warna.hijauTua,
      onPrimary: Warna.kartu,
      secondary: Warna.oranye,
      onSecondary: Warna.tinta,
      surface: Warna.latar,
      onSurface: Warna.tinta,
      error: Warna.tinggiChip,
    ),
    fontFamily: 'Nunito',
  );
  return dasar.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: Warna.latar,
      foregroundColor: Warna.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: judulKecil(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Warna.tinta,
      contentTextStyle: teksLabel(bobot: FontWeight.w600, warna: Warna.kartu),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Warna.kartu,
      contentPadding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Warna.garis, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Warna.garis, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Warna.hijauTua, width: 2),
      ),
    ),
  );
}
