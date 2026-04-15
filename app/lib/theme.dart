import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Cores da marca (Serigrafia Baray) ────────────────────────────────────
// Verde-petróleo: profissional, moderno, diferenciado do azul padrão
const _primaryColor = Color(0xFF00897B);
const _primaryDark = Color(0xFF00695C);
const _primaryLight = Color(0xFFB2DFDB);

// ── Light ────────────────────────────────────────────────────────────────

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _primaryColor,
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: _primaryLight,
  onPrimaryContainer: Color(0xFF003731),
  secondary: Color(0xFF5F6370),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE4E4EC),
  onSecondaryContainer: Color(0xFF1C1C28),
  tertiary: Color(0xFF6B5E7D),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF0DBFF),
  onTertiaryContainer: Color(0xFF26145B),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF9F9F7),
  onSurface: Color(0xFF1A1A18),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF3F3F0),
  surfaceContainer: Color(0xFFEDEDEA),
  surfaceContainerHigh: Color(0xFFE8E8E5),
  surfaceContainerHighest: Color(0xFFE0E0DD),
  onSurfaceVariant: Color(0xFF454542),
  outline: Color(0xFF757570),
  outlineVariant: Color(0xFFC7C7C2),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF2F2F2C),
  onInverseSurface: Color(0xFFF1F1EC),
  inversePrimary: Color(0xFF80CBC4),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF80CBC4),
  onPrimary: _primaryDark,
  primaryContainer: _primaryDark,
  onPrimaryContainer: _primaryLight,
  secondary: Color(0xFFC8C8D2),
  onSecondary: Color(0xFF2E2F3B),
  secondaryContainer: Color(0xFF454557),
  onSecondaryContainer: Color(0xFFE4E4EC),
  tertiary: Color(0xFFD4BCFF),
  onTertiary: Color(0xFF3C2D6E),
  tertiaryContainer: Color(0xFF534485),
  onTertiaryContainer: Color(0xFFF0DBFF),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF1A1A18),
  onSurface: Color(0xFFE8E8E5),
  surfaceContainerLowest: Color(0xFF121210),
  surfaceContainerLow: Color(0xFF222220),
  surfaceContainer: Color(0xFF252523),
  surfaceContainerHigh: Color(0xFF2F2F2D),
  surfaceContainerHighest: Color(0xFF3A3A38),
  onSurfaceVariant: Color(0xFFC7C7C2),
  outline: Color(0xFF8F8F8A),
  outlineVariant: Color(0xFF454542),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFE8E8E5),
  onInverseSurface: Color(0xFF2F2F2C),
  inversePrimary: _primaryColor,
);

// ── Text theme ───────────────────────────────────────────────────────────

TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(letterSpacing: -0.5),
    displayMedium: base.displayMedium?.copyWith(letterSpacing: -0.5),
    displaySmall: base.displaySmall?.copyWith(letterSpacing: -0.25),
    headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -0.25),
    headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -0.25),
    headlineSmall: base.headlineSmall?.copyWith(letterSpacing: 0),
    titleLarge: base.titleLarge?.copyWith(letterSpacing: 0),
    titleMedium: base.titleMedium?.copyWith(letterSpacing: 0.15, fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(letterSpacing: 0.1),
    bodyLarge: base.bodyLarge?.copyWith(letterSpacing: 0.5, height: 1.5),
    bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0.25, height: 1.5),
    bodySmall: base.bodySmall?.copyWith(letterSpacing: 0.4),
    labelLarge: base.labelLarge?.copyWith(letterSpacing: 0.1),
    labelMedium: base.labelMedium?.copyWith(letterSpacing: 0.5),
    labelSmall: base.labelSmall?.copyWith(letterSpacing: 0.5),
  );
}

// ── Light theme ──────────────────────────────────────────────────────────

ThemeData buildLightTheme() {
  final scheme = _lightScheme;
  final baseTextTheme = GoogleFonts.interTextTheme(ThemeData().textTheme);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: _buildTextTheme(baseTextTheme),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerLow,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.outline),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface);
        }
        return TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary, size: 24);
        }
        return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.9,
      minWidth: 80,
      minExtendedWidth: 80,
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant, fontSize: 12),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 8,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ── Dark theme ──────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  final scheme = _darkScheme;
  final baseTextTheme = GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: _buildTextTheme(baseTextTheme),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      color: scheme.surfaceContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.outline),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface);
        }
        return TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary, size: 24);
        }
        return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.9,
      minWidth: 80,
      minExtendedWidth: 80,
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant, fontSize: 12),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 8,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}