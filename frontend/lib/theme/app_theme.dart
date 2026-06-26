import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AgriPulse visual identity — a **Modern AgriTech Dashboard**: a soft
/// cool-grey background, crisp white cards with subtle shadows, a vivid green
/// primary, a lime-green brand gradient and clear status colours.
///
/// One source of truth for every colour, shadow and component style. Screens
/// pull tokens from here (e.g. `AppTheme.primaryGreen`, `AppTheme.brandGradient`,
/// `AppTheme.cardShadow`) instead of hard-coding values, so the whole app stays
/// consistent and easy to rebrand.
///
/// Typography: **Poppins** (bold) for headings, **Inter** for body text.
class AppTheme {
  AppTheme._();

  // ─────────── Brand greens ───────────
  static const Color primaryGreen = Color(0xFF2FB344); // buttons / primary
  static const Color accentGreen = Color(0xFF22C55E); // accent / secondary actions
  static const Color darkGreen = Color(0xFF14532D); // headings / dark green text
  static const Color lightGreen = Color(0xFF2FB344); // icon tint on light surfaces

  // Brand gradient: green → lime. Used on hero headers, primary surfaces, etc.
  static const Color gradientStart = Color(0xFF2FB344);
  static const Color gradientEnd = Color(0xFFA3E635);

  /// The signature green→lime gradient (top-left → bottom-right).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  // ─────────── Surfaces ───────────
  static const Color scaffoldBg = Color(0xFFF5F7FA); // app background (cool grey)
  static const Color surfaceWhite = Color(0xFFFFFFFF); // cards / panels
  static const Color cardGreen = Color(0xFFFFFFFF); // back-compat alias → white card
  static const Color barGreen = Color(0xFFFFFFFF); // back-compat alias → white app bar
  static const Color border = Color(0xFFE6EAF0); // hairline borders / dividers

  // ─────────── Text ───────────
  static const Color textDark = Color(0xFF1E293B); // primary text on light
  static const Color textFaint = Color(0xFF64748B); // secondary / muted text
  static const Color textWhite = Color(0xFFFFFFFF); // text on green buttons/bubbles

  // ─────────── Status colours ───────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // ─────────── Warm accent (tips / warnings) ───────────
  static const Color accentYellow = Color(0xFFF59E0B); // golden highlight = warning
  static const Color softYellow = Color(0xFFFEF7E7); // light yellow tip panels
  static const Color deepAmber = Color(0xFFB45309); // text/icons on yellow

  // ─────────── Elevation ───────────
  /// Subtle, soft shadow for white cards — the "lifted card" look.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Headings use Poppins; pass a colour/size to taste.
  static TextStyle heading(double size,
          {FontWeight weight = FontWeight.w700, Color color = darkGreen, double? height}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// The single light theme used by `MaterialApp`.
  static ThemeData light() {
    const ColorScheme scheme = ColorScheme.light(
      primary: primaryGreen,
      onPrimary: Colors.white,
      secondary: accentGreen,
      onSecondary: Colors.white,
      tertiary: accentYellow,
      surface: surfaceWhite,
      onSurface: textDark,
      error: danger,
    );

    // Inter for body text; Poppins for the large display/headline/title roles.
    final base = ThemeData(brightness: Brightness.light);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: textDark, displayColor: textDark)
        .copyWith(
          displayLarge: GoogleFonts.poppins(textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w700, color: darkGreen),
          displayMedium: GoogleFonts.poppins(textStyle: base.textTheme.displayMedium, fontWeight: FontWeight.w700, color: darkGreen),
          displaySmall: GoogleFonts.poppins(textStyle: base.textTheme.displaySmall, fontWeight: FontWeight.w700, color: darkGreen),
          headlineLarge: GoogleFonts.poppins(textStyle: base.textTheme.headlineLarge, fontWeight: FontWeight.w700, color: darkGreen),
          headlineMedium: GoogleFonts.poppins(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w700, color: darkGreen),
          headlineSmall: GoogleFonts.poppins(textStyle: base.textTheme.headlineSmall, fontWeight: FontWeight.w700, color: darkGreen),
          titleLarge: GoogleFonts.poppins(textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w600, color: darkGreen),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: surfaceWhite,
      canvasColor: scaffoldBg,
      iconTheme: const IconThemeData(color: lightGreen),
      textTheme: textTheme,

      // Clean white app bar with a Poppins dark-green title.
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: darkGreen,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: darkGreen,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: darkGreen),
      ),

      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(8),
      ),

      listTileTheme: const ListTileThemeData(
        textColor: textDark,
        iconColor: lightGreen,
      ),

      // Solid green primary buttons with white text, rounded 14.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: primaryGreen),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),

      // Icon-based navigation, styled to the new palette.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryGreen.withValues(alpha: 0.14),
        elevation: 3,
        shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.08),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primaryGreen : textFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primaryGreen : textFaint,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceWhite,
        indicatorColor: primaryGreen.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: primaryGreen),
        unselectedIconTheme: const IconThemeData(color: textFaint),
        selectedLabelTextStyle: GoogleFonts.inter(color: primaryGreen, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: GoogleFonts.inter(color: textFaint, fontWeight: FontWeight.w500),
      ),

      // Inputs: white field, light border, dark text, green focus, rounded 12.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        hintStyle: const TextStyle(color: textFaint),
        labelStyle: const TextStyle(color: textFaint),
        floatingLabelStyle: const TextStyle(color: primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: darkGreen,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(color: textDark, height: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        actionTextColor: gradientEnd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),

      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: textDark),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: primaryGreen.withValues(alpha: 0.10),
        labelStyle: GoogleFonts.inter(color: primaryGreen, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryGreen),
    );
  }
}
