import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parachute App Theme
///
/// Unified theme for the entire Parachute application.
/// Features a nature-inspired color palette with forest green primary
/// and blue secondary colors, using Inter font family.

class AppColors {
  // Light Mode Colors
  static const lightPrimary = Color(0xFF2E7D32); // Forest green
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFA5D6A7);
  static const lightOnPrimaryContainer = Color(0xFF1B5E20);
  static const lightSecondary = Color(0xFF1976D2); // Blue for digital/tech
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightTertiary = Color(0xFF7B1FA2); // Purple accent
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFD32F2F);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFCDD2);
  static const lightOnErrorContainer = Color(0xFF410002);
  static const lightInversePrimary = Color(0xFF81C784);
  static const lightShadow = Color(0xFF000000);
  static const lightSurface = Color(0xFFFAFAFA);
  static const lightOnSurface = Color(0xFF1C1C1C);
  static const lightAppBarBackground = Color(0xFFA5D6A7);

  // Dark Mode Colors
  static const darkPrimary = Color(0xFF81C784); // Light green for dark mode
  static const darkOnPrimary = Color(0xFF1B5E20);
  static const darkPrimaryContainer = Color(0xFF2E7D32);
  static const darkOnPrimaryContainer = Color(0xFFA5D6A7);
  static const darkSecondary = Color(0xFF64B5F6); // Light blue
  static const darkOnSecondary = Color(0xFF0D47A1);
  static const darkTertiary = Color(0xFFBA68C8); // Light purple
  static const darkOnTertiary = Color(0xFF4A148C);
  static const darkError = Color(0xFFEF5350);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFCDD2);
  static const darkInversePrimary = Color(0xFF2E7D32);
  static const darkShadow = Color(0xFF000000);
  static const darkSurface = Color(0xFF121212);
  static const darkOnSurface = Color(0xFFE0E0E0);
  static const darkAppBarBackground = Color(0xFF2E7D32);
}

class AppFontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

class AppTheme {
  /// Light theme for Parachute
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightOnPrimary,
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightOnPrimaryContainer,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.lightOnSecondary,
      tertiary: AppColors.lightTertiary,
      onTertiary: AppColors.lightOnTertiary,
      error: AppColors.lightError,
      onError: AppColors.lightOnError,
      errorContainer: AppColors.lightErrorContainer,
      onErrorContainer: AppColors.lightOnErrorContainer,
      inversePrimary: AppColors.lightInversePrimary,
      shadow: AppColors.lightShadow,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
    ),
    brightness: Brightness.light,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightAppBarBackground,
      foregroundColor: AppColors.lightOnPrimaryContainer,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: AppFontSizes.titleLarge,
        fontWeight: FontWeight.w600,
        color: AppColors.lightOnPrimaryContainer,
      ),
    ),
    textTheme: _buildTextTheme(),
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.lightPrimary,
      unselectedItemColor: AppColors.lightOnSurface.withValues(alpha: 0.6),
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.lightPrimary,
      foregroundColor: AppColors.lightOnPrimary,
      elevation: 4,
    ),
    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  /// Dark theme for Parachute
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkOnPrimary,
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.darkOnPrimaryContainer,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkOnSecondary,
      tertiary: AppColors.darkTertiary,
      onTertiary: AppColors.darkOnTertiary,
      error: AppColors.darkError,
      onError: AppColors.darkOnError,
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.darkOnErrorContainer,
      inversePrimary: AppColors.darkInversePrimary,
      shadow: AppColors.darkShadow,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
    ),
    brightness: Brightness.dark,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkAppBarBackground,
      foregroundColor: AppColors.darkOnPrimaryContainer,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: AppFontSizes.titleLarge,
        fontWeight: FontWeight.w600,
        color: AppColors.darkOnPrimaryContainer,
      ),
    ),
    textTheme: _buildTextTheme(),
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.darkPrimary,
      unselectedItemColor: AppColors.darkOnSurface.withValues(alpha: 0.6),
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkPrimary,
      foregroundColor: AppColors.darkOnPrimary,
      elevation: 4,
    ),
    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  /// Build text theme using Inter font
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: AppFontSizes.displayLarge,
        fontWeight: FontWeight.normal,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: AppFontSizes.displayMedium,
        fontWeight: FontWeight.normal,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: AppFontSizes.displaySmall,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: AppFontSizes.headlineLarge,
        fontWeight: FontWeight.normal,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: AppFontSizes.headlineMedium,
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: AppFontSizes.headlineSmall,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: AppFontSizes.titleLarge,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: AppFontSizes.titleMedium,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: AppFontSizes.titleSmall,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: AppFontSizes.labelLarge,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: AppFontSizes.labelMedium,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: AppFontSizes.labelSmall,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: AppFontSizes.bodyLarge,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: AppFontSizes.bodyMedium,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: AppFontSizes.bodySmall,
        fontWeight: FontWeight.normal,
      ),
    );
  }
}
