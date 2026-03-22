import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Colors ---
  static const primary = Color(0xFF000666);
  static const primaryContainer = Color(0xFF1A237E);
  static const surface = Color(0xFFF9F9F9);
  static const surfaceLow = Color(0xFFF3F3F3);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFEEEEEE);
  static const onSurface = Color(0xFF1A1C1C);
  static const onSurfaceVariant = Color(0xFF454652);
  static const secondary = Color(0xFF785900);
  static const secondaryContainer = Color(0xFFFDC003);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const outline = Color(0xFF767683);
  static const outlineVariant = Color(0xFFC6C5D4);
  static const inverseSurface = Color(0xFF2F3131);

  // --- Gradient ---
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  // --- Shadows ---
  static final ambientShadow = BoxShadow(
    offset: const Offset(0, 4),
    blurRadius: 16,
    color: const Color(0xFF1A237E).withOpacity(0.06),
  );

  // --- Decorations ---
  static BoxDecoration glassCard({double radius = 12}) => BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [ambientShadow],
      );

  static BoxDecoration surfaceCard({double radius = 8}) => BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [ambientShadow],
      );

  static BoxDecoration gradientBox({double radius = 12}) => BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration tonalSection({double radius = 8}) => BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(radius),
      );

  // --- Text Styles ---
  static TextStyle headline(double size,
          {FontWeight weight = FontWeight.bold, Color? color}) =>
      GoogleFonts.manrope(
          fontSize: size, fontWeight: weight, color: color ?? onSurface);

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.normal, Color? color}) =>
      GoogleFonts.inter(
          fontSize: size, fontWeight: weight, color: color ?? onSurface);

  static TextStyle label(double size, {Color? color}) => GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color ?? onSurfaceVariant);

  // --- Risk colors ---
  static Color riskColor(int score) {
    if (score >= 70) return const Color(0xFF2E7D32);
    if (score >= 40) return const Color(0xFFF57F17);
    return error;
  }

  static Color riskBackground(int score) {
    if (score >= 70) return const Color(0xFFE8F5E9);
    if (score >= 40) return const Color(0xFFFFF8E1);
    return errorContainer;
  }

  static String riskLabel(int score) {
    if (score >= 70) return 'Low Risk';
    if (score >= 40) return 'Medium Risk';
    return 'High Risk';
  }

  // --- MaterialTheme ---
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryContainer,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: primaryContainer,
          surface: surface,
          onSurface: onSurface,
          error: error,
          secondary: secondary,
          secondaryContainer: secondaryContainer,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: surface,
        cardTheme: CardThemeData(
          color: surfaceLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFE8E8E8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryContainer, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          labelStyle: GoogleFonts.inter(fontSize: 12, color: onSurfaceVariant),
          hintStyle: GoogleFonts.inter(fontSize: 12, color: outline),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primaryContainer),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surfaceLowest,
          indicatorColor: primaryContainer.withOpacity(0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.inter(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? primary : onSurfaceVariant,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 20,
              color: selected ? primary : onSurfaceVariant,
            );
          }),
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceContainer,
          labelStyle: GoogleFonts.inter(fontSize: 10, color: onSurface),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: BorderSide.none,
        ),
      );
}
