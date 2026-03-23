import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFF000666);
  static const primaryContainer = Color(0xFF1A237E);
  static const primaryFixed = Color(0xFFE0E0FF);
  static const surface = Color(0xFFF9F9F9);
  static const surfaceLow = Color(0xFFF3F3F3);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFEEEEEE);
  static const surfaceContainerHigh = Color(0xFFE8E8E8);
  static const onSurface = Color(0xFF1A1C1C);
  static const onSurfaceVariant = Color(0xFF454652);
  static const secondary = Color(0xFF785900);
  static const secondaryContainer = Color(0xFFFDC003);
  static const success = Color(0xFF2E7D32);
  static const successContainer = Color(0xFFE8F5E9);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const outline = Color(0xFF767683);
  static const outlineVariant = Color(0xFFC6C5D4);
  static const inverseSurface = Color(0xFF2F3131);
  static const monitorBackground = Color(0xFF101216);
  static const monitorBackgroundSoft = Color(0xFF1A1C1C);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static const warmBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF9F9F9), Color(0xFFF1F2F8)],
  );

  static const darkMonitorGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF181A1E), Color(0xFF090A0D)],
  );

  static final ambientShadow = BoxShadow(
    offset: const Offset(0, 16),
    blurRadius: 32,
    color: primaryContainer.withValues(alpha: 0.08),
  );

  static final elevatedShadow = BoxShadow(
    offset: const Offset(0, 20),
    blurRadius: 48,
    color: primaryContainer.withValues(alpha: 0.14),
  );

  static BoxDecoration glassCard({double radius = 28}) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [ambientShadow],
      );

  static BoxDecoration surfaceCard({double radius = 24}) => BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.18)),
        boxShadow: [ambientShadow],
      );

  static BoxDecoration gradientBox({double radius = 24}) => BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [elevatedShadow],
      );

  static BoxDecoration tonalSection({double radius = 24}) => BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration darkGlass({double radius = 24}) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      );

  static BoxDecoration editorialPageBackground({bool dark = false}) =>
      BoxDecoration(
        gradient: dark ? darkMonitorGradient : warmBackground,
      );

  static TextStyle headline(
    double size, {
    FontWeight weight = FontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color ?? onSurface,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? onSurface,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle label(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 1.2,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color ?? onSurfaceVariant,
      );

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

  static Color riskLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFF7F1010);
      case 'HIGH':
        return error;
      case 'MEDIUM':
        return const Color(0xFFF57F17);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static Color riskLevelBackground(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFF8D7DA);
      case 'HIGH':
        return errorContainer;
      case 'MEDIUM':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  static Color severityColor(String severity) => riskLevelColor(severity);

  static Color severityBackground(String severity) =>
      riskLevelBackground(severity);

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
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: primaryContainer, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            color: onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: GoogleFonts.inter(fontSize: 12, color: outline),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: outlineVariant.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceContainer,
          labelStyle: GoogleFonts.inter(fontSize: 10, color: onSurface),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide.none,
        ),
        dividerColor: Colors.transparent,
      );
}
