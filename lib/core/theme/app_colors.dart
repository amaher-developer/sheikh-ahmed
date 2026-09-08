import 'package:flutter/material.dart';

/// Brand palette for the "الشيخ أحمد" app.
///
/// Most of the app's screens read colors directly off this class as static
/// fields (`AppColors.background`, not `Theme.of(context).colorScheme...`)
/// rather than through Flutter's Theme mechanism. To make dark mode
/// actually repaint those screens — not just switch a Material default no
/// custom widget reads — the theme-responsive fields below are mutable and
/// reassigned by [applyBrightness], called once per frame from the app
/// root before children build. Brand colors (primary green, gold) stay
/// fixed across both modes; only surfaces/text/borders swap.
class AppColors {
  AppColors._();

  // Brand colors — deliberately the same in both themes.
  static const primary = Color(0xFF2F5D3F);
  static const primaryDark = Color(0xFF1C3325);
  static const gold = Color(0xFFB0813A);
  static const goldLight = Color(0xFFE0B45F);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textOnPrimaryMuted = Color(0xFFA8C4A8);
  static const textDanger = Color(0xFFB3261E);

  static bool isDark = false;

  // ---- Light values ----
  // Not private: AppTheme.light needs these as *fixed* light-mode values
  // (it must stay the light theme no matter what the app's current mode
  // is), which the mutable fields below can't safely provide — see
  // app_theme.dart's comment.
  static const lightPrimaryTint = Color(0xFFEEF5E7);
  static const lightGoldTint = Color(0xFFF9F0E0);
  static const lightBackground = Color(0xFFF7F5EF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightAyahBg = Color(0xFFF0F6EA);

  /// The Mus'haf page itself — a warm off-white rather than the flat
  /// #FFFFFF used for cards elsewhere. Printed Mus'hafs are on cream
  /// paper, and pure white behind dense black Uthmani script at reading
  /// length is noticeably harsher.
  static const lightMushafPage = Color(0xFFFCF8F0);

  /// Ink for the printed-page reader. Near-black with a trace of the
  /// app green rather than pure #000, which on cream reads as a hole
  /// punched in the paper.
  static const lightMushafInk = Color(0xFF17251B);
  static const darkMushafInk = Color(0xFFE6E2D4);

  /// لفظ الجلالة, which the printed Mus'haf sets in red.
  static const lightJalalah = Color(0xFFB3261E);
  static const darkJalalah = Color(0xFFE0736A);
  static const lightTextPrimary = Color(0xFF1C3325);
  static const lightTextSecondary = Color(0xFF9AA093);
  static const lightTextMuted = Color(0xFFB7BCAE);
  static const lightBorder = Color(0xFFF1EDE0);
  static const lightDivider = Color(0xFFDCDFD2);
  static const lightShadow = Color(0x1A1F3B2A);
  static const lightChipBg = Color(0xFFF2F4EE);
  static const lightIconMuted = Color(0xFFC7CBBE);

  // ---- Dark values ---- (same "not private" reasoning, for AppTheme.dark)
  static const darkPrimaryTint = Color(0xFF17271D);
  static const darkGoldTint = Color(0xFF2B2114);
  static const darkBackground = Color(0xFF121814);
  static const darkSurface = Color(0xFF1B231C);
  static const darkAyahBg = Color(0xFF1A2A1E);
  static const darkMushafPage = Color(0xFF17201A);
  static const darkTextPrimary = Color(0xFFEDF2EA);
  static const darkTextSecondary = Color(0xFF9DAA9A);
  static const darkTextMuted = Color(0xFF6E7A6C);
  static const darkBorder = Color(0xFF2A342B);
  static const darkDivider = Color(0xFF2F3930);
  static const darkShadow = Color(0x40000000);
  static const darkChipBg = Color(0xFF232D24);
  static const darkIconMuted = Color(0xFF57624F);

  // ---- Theme-responsive fields (mutated by applyBrightness) ----
  static Color primaryTint = lightPrimaryTint;
  static Color goldTint = lightGoldTint;
  static Color background = lightBackground;
  static Color mushafPage = lightMushafPage;
  static Color mushafInk = lightMushafInk;
  static Color jalalah = lightJalalah;
  static Color surface = lightSurface;
  static Color ayahBg = lightAyahBg;
  static Color textPrimary = lightTextPrimary;
  static Color textSecondary = lightTextSecondary;
  static Color textMuted = lightTextMuted;
  static Color border = lightBorder;
  static Color divider = lightDivider;
  static Color shadow = lightShadow;
  static Color chipBg = lightChipBg;
  static Color iconMuted = lightIconMuted;

  static void applyBrightness(bool dark) {
    if (isDark == dark) return;
    isDark = dark;
    primaryTint = dark ? darkPrimaryTint : lightPrimaryTint;
    mushafPage = dark ? darkMushafPage : lightMushafPage;
    mushafInk = dark ? darkMushafInk : lightMushafInk;
    jalalah = dark ? darkJalalah : lightJalalah;
    goldTint = dark ? darkGoldTint : lightGoldTint;
    background = dark ? darkBackground : lightBackground;
    surface = dark ? darkSurface : lightSurface;
    ayahBg = dark ? darkAyahBg : lightAyahBg;
    textPrimary = dark ? darkTextPrimary : lightTextPrimary;
    textSecondary = dark ? darkTextSecondary : lightTextSecondary;
    textMuted = dark ? darkTextMuted : lightTextMuted;
    border = dark ? darkBorder : lightBorder;
    divider = dark ? darkDivider : lightDivider;
    shadow = dark ? darkShadow : lightShadow;
    chipBg = dark ? darkChipBg : lightChipBg;
    iconMuted = dark ? darkIconMuted : lightIconMuted;
  }
}
