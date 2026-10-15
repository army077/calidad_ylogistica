// lib/config/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta y temas globales de Asia Robótica.
///
/// Refinamiento conservador 2026:
/// - Rojo del logo ligeramente desaturado (menos vibración óptica)
/// - Grises con tinte cálido sutil (identidad Guadalajara, no Scandi frío)
/// - Acento ámbar como secundario (botones secundarios, badges)
/// - Soporta dark + light (sigue el modo del sistema)
class AppTheme {
  // ============================================================
  // PALETA DE MARCA (independiente del modo)
  // ============================================================

  /// Rojo del dragón — ligeramente desaturado vs. logo puro para evitar
  /// vibración óptica sobre fondos oscuros.
  static const Color primaryColor = Color(0xFFE63946);

  /// Rojo profundo — botones secundarios sobre primario, badges, hovers.
  static const Color primaryDeep = Color(0xFF5B1A1F);

  /// Ámbar tapatío — acento secundario cálido (sol GDL, sin caer en cliché).
  static const Color accentAmber = Color(0xFFF2A65A);
  static const Color accentAmberDeep = Color(0xFFB97A3A);

  // --- Aliases legacy para no romper código existente que usa AppTheme.X ---
  static const Color backgroundColor = Color(0xFF14110F);
  static const Color surfaceColor = Color(0xFF1F1B19);
  static const Color surfaceContainer = Color(0xFF2A2522);
  static const Color textColor = Color(0xFFF5F1ED);
  static const Color textColorSecondary = Color(0xFFB8B0A9);

  // ============================================================
  // TOKENS SEMÁNTICOS (feedback / estado)
  // ============================================================

  /// Éxito — verde menta apagado, NO semáforo.
  static const Color success = Color(0xFF5BBF8A);

  /// Información neutral.
  static const Color info = Color(0xFF6FA8DC);

  /// Advertencia — ámbar (combina con el secondary).
  static const Color warning = Color(0xFFF2B04A);

  /// Error genérico — igual al primario (la marca YA es rojo).
  static const Color danger = primaryColor;

  /// Error grave / sanción.
  static const Color dangerDark = primaryDeep;

  // ============================================================
  // TEMAS
  // ============================================================

  /// Tema oscuro (default). Alias retro-compatible.
  static ThemeData get asiaRoboticaTheme => _buildDarkTheme();
  static ThemeData get darkTheme => _buildDarkTheme();
  static ThemeData get lightTheme => _buildLightTheme();

  static ThemeData _buildDarkTheme() {
    const background = Color(0xFF14110F);
    const surface = Color(0xFF1F1B19);
    const surfaceContainerLow = Color(0xFF24201D);
    const surfaceContainerMid = Color(0xFF2A2522);
    const surfaceContainerHigh = Color(0xFF34302D);
    const surfaceContainerHighest = Color(0xFF3F3A36);
    const outline = Color(0xFF4A4441);
    const outlineVariant = Color(0xFF3A3633);
    const onSurface = Color(0xFFF5F1ED);
    const onSurfaceVariant = Color(0xFFB8B0A9);

    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryDeep,
      onPrimaryContainer: Color(0xFFFFDAD8),
      secondary: accentAmber,
      onSecondary: Color(0xFF1A1A1A),
      secondaryContainer: accentAmberDeep,
      onSecondaryContainer: Color(0xFFFFEBD2),
      tertiary: Color(0xFFB8B0A9),
      onTertiary: Color(0xFF1A1A1A),
      error: primaryColor,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainerMid,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,
    );

    return _baseTheme(
      colorScheme: colorScheme,
      scaffoldBg: background,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
    );
  }

  static ThemeData _buildLightTheme() {
    const background = Color(0xFFFBF8F5);
    const surface = Color(0xFFFFFFFF);
    const surfaceContainerLow = Color(0xFFF5F1ED);
    const surfaceContainerMid = Color(0xFFF0EAE4);
    const surfaceContainerHigh = Color(0xFFEDE7E1);
    const surfaceContainerHighest = Color(0xFFE5DED7);
    const outline = Color(0xFFC9C0B8);
    const outlineVariant = Color(0xFFE5DED7);
    const onSurface = Color(0xFF1A1715);
    const onSurfaceVariant = Color(0xFF5C544E);

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFDAD8),
      onPrimaryContainer: primaryDeep,
      secondary: accentAmberDeep,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFEBD2),
      onSecondaryContainer: Color(0xFF4A2D14),
      tertiary: Color(0xFF5C544E),
      onTertiary: Colors.white,
      error: primaryColor,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainerMid,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,
    );

    return _baseTheme(
      colorScheme: colorScheme,
      scaffoldBg: background,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
    );
  }

  // Base compartida: misma "forma" para dark y light
  static ThemeData _baseTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: colorScheme.surface,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: onSurfaceVariant),
        bodyLarge: TextStyle(color: onSurface),
        bodyMedium: TextStyle(color: onSurfaceVariant),
        bodySmall: TextStyle(color: onSurfaceVariant),
        labelLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.getFont(
            'Inter',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.getFont(
            'Inter',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: onSurfaceVariant.withValues(alpha: 0.7)),
        labelStyle: TextStyle(color: onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
      ),
      iconTheme: IconThemeData(color: onSurface),
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.getFont('Inter',
            color: onSurface, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // DECORACIONES DE PANTALLA
  // ============================================================

  /// Gradiente para fondos de pantalla. Cambia según el brillo del theme.
  static BoxDecoration screenDecorationFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [
                Color(0xFF14110F),
                Color(0xFF1F1B19),
                Color(0xFF2A2522),
              ]
            : const [
                Color(0xFFFBF8F5),
                Color(0xFFF5F1ED),
                Color(0xFFEDE7E1),
              ],
      ),
    );
  }

  /// Versión legacy (dark fija). Usa `screenDecorationFor(context)` cuando
  /// puedas para soportar light mode.
  static BoxDecoration get screenDecoration {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF14110F),
          Color(0xFF1F1B19),
          Color(0xFF2A2522),
        ],
      ),
    );
  }
}
