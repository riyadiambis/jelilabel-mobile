import 'package:flutter/material.dart';

import 'warna.dart';

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

ThemeData temaJeliLabel() {
  final dasar = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Warna.latar,
    colorScheme: const ColorScheme.light(
      primary: Warna.hijauTua,
      onPrimary: Colors.white,
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
      titleTextStyle: fredoka(20),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Warna.tinta,
      contentTextStyle: nunito(14, FontWeight.w600, warna: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Warna.kartu,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
