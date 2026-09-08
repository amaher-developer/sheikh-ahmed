import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'khatim_pattern.dart';

/// Shared curved, khatim-textured header for every screen below Home.
/// [bottomInset] is how much extra height to leave below [child] before
/// the header's bottom edge — content below overlaps upward by 30-46px
/// depending on the screen, matching the mockups.
class SubScreenHeader extends StatelessWidget {
  final Widget child;
  final double bottomPadding;

  const SubScreenHeader({
    super.key,
    required this.child,
    this.bottomPadding = 50,
  });

  @override
  Widget build(BuildContext context) {
    // The colored background stays full-bleed under the status bar (for the
    // immersive look), but the title/content must clear it — otherwise it
    // renders underneath the battery/clock area on real devices.
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        color: AppColors.primary,
        padding: EdgeInsets.fromLTRB(
          22,
          statusBarHeight + 16,
          22,
          bottomPadding,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: KhatimPattern(opacity: 0.15)),
            child,
          ],
        ),
      ),
    );
  }
}

class SubScreenTitleRow extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SubScreenTitleRow({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Only drawn when there's actually somewhere to go back to —
            // QuranScreen/RadioScreen reuse this row as a tab root (never
            // pushed), where the arrow used to sit there doing nothing on
            // tap. Rebuilds on route changes via the Builder + canPop.
            Builder(
              builder: (context) {
                if (!Navigator.canPop(context)) return const SizedBox.shrink();
                return Padding(
                  // Hit target padded to ~40dp — a bare 20x20 icon is
                  // below the ~44dp minimum touch target and easy to miss.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.maybePop(context),
                    // arrow_back, not arrow_forward. Every directional icon
                    // in Material carries matchTextDirection, so Flutter
                    // already mirrors the glyph per language: back points
                    // left in English and right in Arabic, on its own.
                    // Naming "forward" here was a manual RTL compensation
                    // that the framework had already made — the two
                    // cancelled out, leaving the arrow pointing inward, the
                    // wrong way, in Arabic.
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.6,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}
