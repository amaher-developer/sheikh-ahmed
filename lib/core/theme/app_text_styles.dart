import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Cairo type scale, loaded from the bundled variable font (see pubspec.yaml
/// / assets/fonts) rather than fetched at runtime — a prayer-times app can't
/// depend on reaching Google's font CDN to render its own text.
/// Line-heights are deliberately generous for Arabic — tashkeel and
/// descenders need more room than Latin text at the same size.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _cairo(
    double size,
    FontWeight weight,
    Color color, {
    double height = 1.6,
  }) => TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  // Getters, not `static` fields: a plain `static TextStyle x = _cairo(...)`
  // is lazily initialized *once* and then cached for the process lifetime,
  // freezing whatever AppColors.textPrimary/etc. happened to be at that
  // first access — dark mode toggling afterward never re-evaluates it. That
  // was the bug behind text staying light-mode-colored (unreadable on a
  // dark background) even after switching themes. A getter re-reads the
  // current AppColors value on every build instead.
  static TextStyle get heading =>
      _cairo(27, FontWeight.w800, AppColors.textPrimary, height: 1.35);
  static TextStyle get title =>
      _cairo(17, FontWeight.w800, AppColors.textPrimary, height: 1.5);
  static TextStyle get subtitle =>
      _cairo(13.5, FontWeight.w700, AppColors.textPrimary, height: 1.6);
  static TextStyle get body =>
      _cairo(14.5, FontWeight.w600, AppColors.textPrimary, height: 2.15);
  static TextStyle get caption =>
      _cairo(11, FontWeight.w500, AppColors.textSecondary, height: 1.6);
  static TextStyle get label =>
      _cairo(10, FontWeight.w600, AppColors.textSecondary, height: 1.5);
  static TextStyle get accent =>
      _cairo(12.5, FontWeight.w700, AppColors.gold, height: 1.7);
  static TextStyle get navLabel =>
      _cairo(9, FontWeight.w600, AppColors.textMuted, height: 1.4);

  /// For dhikr text, which needs the most breathing room.
  static TextStyle get quranic =>
      _cairo(15, FontWeight.w600, AppColors.textPrimary, height: 2.2);

  /// For actual Quranic verse text. Must use AmiriQuran, not Cairo: Cairo
  /// has no glyphs for the Uthmani marks the Quran API returns (sukun
  /// U+06E1, waqf signs, superscript madda, the U+08Fx tanween set), so
  /// verses set in Cairo render with missing and misplaced marks.
  /// The face used for Quranic text, switchable by the reader (see
  /// QuranFontNotifier). Mutable static, matching how [AppColors] handles
  /// the theme in this codebase.
  static String mushafFamily = 'ScheherazadeNew';

  /// Whether Quranic text is set in the face's bold weight. Only
  /// ScheherazadeNew actually ships one — AmiriQuran has a single weight,
  /// so Flutter would synthesise a smeared fake bold for it, which on
  /// dense Uthmani diacritics turns into mush. [mushaf] guards against
  /// that rather than trusting the caller.
  static bool mushafBold = false;

  static TextStyle mushaf({double fontSize = 21, double height = 2.0}) =>
      TextStyle(
        fontFamily: mushafFamily,
        fontSize: fontSize,
        height: height,
        fontWeight: mushafBold && mushafFamily == 'ScheherazadeNew'
            ? FontWeight.w700
            : FontWeight.w400,
        color: AppColors.textPrimary,
      );
}
