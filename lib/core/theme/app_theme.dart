import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // `light`/`dark` must each represent ONE fixed brightness regardless of
  // the app's current mode, so — unlike most of this app's widgets — they
  // deliberately do *not* read AppColors's mutable background/surface/
  // border fields (those track whatever brightness is currently applied,
  // which is exactly the wrong source here: e.g. if the app starts in dark
  // mode, those fields start dark, and `light` would wrongly bake dark
  // values into what's supposed to be the light theme). They use
  // AppColors's fixed light*/dark* constants instead.
  //
  // These are getters rather than plain `static` fields on general
  // principle (a static field would still only evaluate once and then
  // serve a stale ThemeData instance forever), even though with fixed
  // constants as inputs there's no *value* that can go stale here.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightBackground,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.gold,
      surface: AppColors.lightSurface,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 0.5,
    ),
    splashFactory: InkRipple.splashFactory,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.darkBackground,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.gold,
      surface: AppColors.darkSurface,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 0.5,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
