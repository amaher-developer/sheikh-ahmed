import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class QuickAccessItem {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final bool gold;
  final VoidCallback onTap;

  const QuickAccessItem({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.onTap,
    this.gold = false,
  });
}

class QuickAccessGrid extends StatelessWidget {
  final List<QuickAccessItem> items;

  const QuickAccessGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // A fixed extent (not childAspectRatio) keeps card height constant
        // regardless of screen width — with aspectRatio, a wider real
        // device than the design mockup assumed made cards proportionally
        // shorter, which combined with a larger system font size clipped
        // the title/subtitle via RenderFlex overflow. 132 (not the ~122
        // measured minimum) leaves real headroom for larger system font
        // scales instead of reproducing the same overflow at a new number.
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return _QuickAccessCard(item: item);
      },
    );
  }
}

class _QuickAccessCard extends StatefulWidget {
  final QuickAccessItem item;
  const _QuickAccessCard({required this.item});

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final iconBg = item.gold ? AppColors.goldTint : AppColors.primaryTint;
    final iconColor = item.gold ? AppColors.gold : AppColors.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: item.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 13),
              Text(
                item.titleKey.tr(),
                style: AppTextStyles.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitleKey.tr(),
                style: AppTextStyles.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
