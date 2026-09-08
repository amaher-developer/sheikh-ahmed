import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

/// Standard Zakat nisab threshold: the value of 85g of gold. Gold price
/// itself isn't fetched live (no free reliable price API without a key) —
/// the user enters today's price per gram themselves.
const _nisabGrams = 85.0;
const _zakatRate = 0.025;

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  final _cashController = TextEditingController();
  final _goldGramsController = TextEditingController();
  final _goldPriceController = TextEditingController();
  final _debtsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The summary card below is computed from these controllers' text in
    // build(), so it needs to rebuild on every keystroke — not just the
    // individual _AmountField, which only redraws its own label/border.
    for (final c in [
      _cashController,
      _goldGramsController,
      _goldPriceController,
      _debtsController,
    ]) {
      c.addListener(_recalculate);
    }
  }

  void _recalculate() => setState(() {});

  @override
  void dispose() {
    _cashController.dispose();
    _goldGramsController.dispose();
    _goldPriceController.dispose();
    _debtsController.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => parseLocalizedNumber(c.text);

  @override
  Widget build(BuildContext context) {
    final cash = _num(_cashController);
    final goldGrams = _num(_goldGramsController);
    final goldPrice = _num(_goldPriceController);
    final debts = _num(_debtsController);

    final goldValue = goldGrams * goldPrice;
    final nisabValue = _nisabGrams * goldPrice;
    final totalWealth = (cash + goldValue - debts).clamp(0, double.infinity);
    final hasNisabInput = goldPrice > 0;
    final isDue = hasNisabInput && totalWealth >= nisabValue;
    final zakatDue = isDue ? totalWealth * _zakatRate : 0.0;

    // Scaffold, not a bare CustomScrollView: this screen (unlike Azkar or
    // Qibla) contains TextFields, which throw "No Material widget found"
    // without a Material ancestor. Other screens get one for free from
    // AppShell's Scaffold, but this one is pushed standalone via
    // MaterialPageRoute (see home_screen.dart / settings_screen.dart).
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SubScreenHeader(
              bottomPadding: 50,
              child: SubScreenTitleRow(title: 'zakat_screen.title'.tr()),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.10),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'zakat_screen.your_wealth'.tr(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AmountField(
                          label: 'zakat_screen.cash_savings'.tr(),
                          controller: _cashController,
                        ),
                        const SizedBox(height: 12),
                        _AmountField(
                          label: 'zakat_screen.gold_grams'.tr(),
                          controller: _goldGramsController,
                          suffix: 'g',
                        ),
                        const SizedBox(height: 12),
                        _AmountField(
                          label: 'zakat_screen.gold_price'.tr(),
                          controller: _goldPriceController,
                        ),
                        const SizedBox(height: 12),
                        _AmountField(
                          label: 'zakat_screen.debts'.tr(),
                          controller: _debtsController,
                        ),
                      ],
                    ),
                  ),
                  const OrnamentDivider(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDue ? AppColors.primary : AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasNisabInput
                              ? (isDue
                                    ? 'zakat_screen.zakat_due'.tr()
                                    : 'zakat_screen.below_nisab'.tr())
                              : 'zakat_screen.enter_gold_price'.tr(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDue
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppColors.primary,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          zakatDue.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: isDue ? Colors.white : AppColors.primaryDark,
                            height: 1.2,
                          ),
                        ),
                        if (hasNisabInput) ...[
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: (isDue ? Colors.white : AppColors.primary)
                                .withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          _SummaryRow(
                            label: 'zakat_screen.total_wealth'.tr(),
                            value: totalWealth.toStringAsFixed(2),
                            light: isDue,
                          ),
                          const SizedBox(height: 6),
                          _SummaryRow(
                            label: 'zakat_screen.nisab_value'.tr(),
                            value: nisabValue.toStringAsFixed(2),
                            light: isDue,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'zakat_screen.disclaimer'.tr(),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? suffix;

  const _AmountField({
    required this.label,
    required this.controller,
    this.suffix,
  });

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: widget.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Must accept Arabic-Indic digits: the app defaults to Arabic,
            // and an ASCII-only `\d` filter silently swallows every
            // keystroke from an Arabic keypad, leaving the field dead.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.٫]')),
            ],
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              hintText: '0',
              hintStyle: TextStyle(color: AppColors.textMuted),
              suffixText: widget.suffix,
              suffixStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool light;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    final color = light
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: color, height: 1.7),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: light ? Colors.white : AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}
