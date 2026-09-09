import 'package:adhan_dart/adhan_dart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/adhan/adhan_audio.dart';
import '../../../core/adhan/adhan_providers.dart';
import '../../../core/adhan/exact_alarm_providers.dart';
import '../../../core/adhan/overlay_providers.dart';
import '../../../core/app_restart.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/prayer/location_service.dart';
import '../../../core/prayer/prayer_city.dart';
import '../../../core/prayer/prayer_providers.dart';
import '../../../core/prayer/prayer_settings.dart';
import '../../../core/share/share_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';
import '../../qibla/presentation/qibla_screen.dart';
import '../../zakat/presentation/zakat_screen.dart';

class LangOption {
  final String name;
  final String sub;
  final Locale locale;
  LangOption(this.name, this.sub, this.locale);
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _langs = [
    LangOption('العربية', 'Arabic', const Locale('ar')),
    LangOption('English', 'الإنجليزية', const Locale('en')),
  ];

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final settings = ref.watch(prayerSettingsProvider);
    // Watched so this screen rebuilds when the toggle changes; the actual
    // resolved on/off state (including ThemeMode.system) is read from
    // AppColors.isDark, which main.dart keeps in sync every frame.
    ref.watch(themeModeProvider);
    final isDark = AppColors.isDark;
    final adhanSettings = ref.watch(adhanSettingsProvider);
    final notificationTypes = ref.watch(notificationTypeSettingsProvider);
    final exactAlarmsAllowed = ref.watch(exactAlarmsAllowedProvider);
    final canAppearOnTop = ref.watch(overlayPermissionProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SubScreenHeader(
            bottomPadding: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'settings_screen.title'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
              ],
            ),
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
                      Row(
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'settings_screen.app_language'.tr(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._langs.map((lang) {
                        final on =
                            lang.locale.languageCode ==
                            currentLocale.languageCode;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: GestureDetector(
                            onTap: on
                                ? null
                                : () async {
                                    await context.setLocale(lang.locale);
                                    if (context.mounted) {
                                      AppRestart.restart(context);
                                    }
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: on
                                    ? AppColors.primaryTint
                                    : AppColors.chipBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    lang.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      lang.sub,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    on
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 19,
                                    color: on
                                        ? AppColors.primary
                                        : AppColors.iconMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const OrnamentDivider(),
                _SettingsRow(
                  icon: Icons.paid_rounded,
                  titleKey: 'settings_screen.zakat_calculator',
                  subtitleKey: 'settings_screen.zakat_sub',
                  gold: false,
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ZakatScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.explore_rounded,
                  titleKey: 'settings_screen.qibla_direction',
                  subtitleKey: 'settings_screen.qibla_sub',
                  gold: true,
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QiblaScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.ios_share_rounded,
                  titleKey: 'settings_screen.share_app',
                  subtitleKey: 'settings_screen.share_app_sub',
                  gold: false,
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => shareApp(context),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.location_on_rounded,
                  titleKey: 'settings_screen.location',
                  subtitleKey: '',
                  subtitleOverride: _locationSubtitle(settings),
                  gold: false,
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => _openLocationSheet(context, ref),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.explore_outlined,
                  titleKey: 'settings_screen.calculation_method',
                  subtitleKey: '',
                  subtitleOverride: _methodSubtitle(settings),
                  gold: true,
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => _openCalculationMethodSheet(context, ref),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.notifications_active_rounded,
                  titleKey: 'adhan.enable',
                  subtitleKey: 'adhan.enable_sub',
                  gold: true,
                  trailing: Switch(
                    value: adhanSettings.enabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) =>
                        ref.read(adhanSettingsProvider.notifier).setEnabled(v),
                  ),
                ),
                // Only when Android is actually holding reminders back. A
                // permanent row would be noise on every device where exact
                // alarms already work, and would keep offering a system
                // screen whose switch is already on.
                if (!exactAlarmsAllowed) ...[
                  const SizedBox(height: 10),
                  _SettingsRow(
                    icon: Icons.alarm_on_rounded,
                    titleKey: 'settings_screen.exact_alarms',
                    subtitleKey: 'settings_screen.exact_alarms_sub',
                    gold: true,
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: AppColors.iconMuted,
                    ),
                    onTap: ref
                        .read(exactAlarmsAllowedProvider.notifier)
                        .request,
                  ),
                ],
                // Same rule as the row above: shown only while it is
                // actually off. It is the second exemption that lets the
                // adhan start its player from the background, and on
                // phones with aggressive battery managers it is often
                // the one still standing.
                if (!canAppearOnTop) ...[
                  const SizedBox(height: 10),
                  _SettingsRow(
                    icon: Icons.layers_rounded,
                    titleKey: 'settings_screen.appear_on_top',
                    subtitleKey: 'settings_screen.appear_on_top_sub',
                    gold: true,
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: AppColors.iconMuted,
                    ),
                    onTap: ref
                        .read(overlayPermissionProvider.notifier)
                        .request,
                  ),
                ],
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.record_voice_over_rounded,
                  titleKey: 'adhan.voice',
                  subtitleKey: '',
                  subtitleOverride: adhanSettings.voice.nameKey.tr(),
                  gold: false,
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => _openAdhanVoiceSheet(context),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.wb_twilight_rounded,
                  titleKey: 'settings_screen.azkar_notifications',
                  subtitleKey: 'settings_screen.azkar_notifications_sub',
                  gold: false,
                  trailing: Switch(
                    value: notificationTypes.azkarEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => ref
                        .read(notificationTypeSettingsProvider.notifier)
                        .setAzkarEnabled(v),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsRow(
                  icon: Icons.dark_mode_rounded,
                  titleKey: 'settings_screen.dark_mode',
                  subtitleKey: '',
                  subtitleOverride: isDark ? 'مفعّل' : 'مطفأ',
                  gold: false,
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) async {
                      await ref.read(themeModeProvider.notifier).setDark(v);
                      if (context.mounted) AppRestart.restart(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _locationSubtitle(PrayerSettings settings) {
    if (settings.cityId != null) return 'cities.${settings.cityId}'.tr();
    return 'home.current_location'.tr();
  }

  String _methodSubtitle(PrayerSettings settings) {
    final method = 'calculation_methods.${settings.method.name}'.tr();
    final madhab = 'madhab_names.${settings.madhab.name}'.tr();
    return '$method · $madhab';
  }

  void _openLocationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LocationSheet(),
    );
  }

  void _openCalculationMethodSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CalculationMethodSheet(),
    );
  }

  void _openAdhanVoiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdhanVoiceSheet(),
    );
  }

}

class _AdhanVoiceSheet extends ConsumerWidget {
  const _AdhanVoiceSheet();

  MediaItem _previewItem(AdhanVoice voice) => MediaItem(
    id: voice.url,
    title: 'adhan.title'.tr(),
    artist: voice.nameKey.tr(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adhanSettingsProvider);
    final nowUrl = ref.watch(currentMediaItemProvider).valueOrNull?.id;
    final isPlaying =
        ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'adhan.select_voice'.tr(),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'adhan.preview_hint'.tr(),
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            ...kAdhanVoices.map((voice) {
              final on = voice.id == settings.voiceId;
              final isThisPlaying = nowUrl == voice.url && isPlaying;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () async {
                    await ref
                        .read(adhanSettingsProvider.notifier)
                        .setVoice(voice);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primaryTint : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            try {
                              await toggleAudio(ref, _previewItem(voice));
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'radio_screen.playback_error'.tr(),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isThisPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            voice.nameKey.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          on
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: on
                              ? AppColors.primary
                              : AppColors.iconMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final String? subtitleOverride;
  final bool gold;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.gold,
    required this.trailing,
    this.subtitleOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: gold ? AppColors.goldTint : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: gold ? AppColors.gold : AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleKey.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // Calculation-method subtitles can be long ("University
                  // of Islamic Sciences, Karachi · Hanafi") — cap at 2
                  // lines instead of letting the row grow unpredictably.
                  subtitleOverride ?? subtitleKey.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Bottom sheet: pick a preset city, or fetch the device's current GPS fix.
/// Keeps its own loading/error state — a failed GPS fetch (permission
/// denied, location services off) shows an inline message instead of
/// crashing or leaving the sheet stuck.
class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet();

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  bool _locating = false;
  String? _error;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();
      await ref
          .read(prayerSettingsProvider.notifier)
          .setCoordinates(result.latitude, result.longitude);
      if (mounted) Navigator.of(context).pop();
    } on LocationServiceDisabledException {
      setState(() => _error = 'settings_screen.location_service_disabled'.tr());
    } on LocationPermissionDeniedException {
      setState(
        () => _error = 'settings_screen.location_permission_denied'.tr(),
      );
    } catch (_) {
      setState(
        () => _error = 'settings_screen.location_permission_denied'.tr(),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(prayerSettingsProvider);

    return _SheetShell(
      titleKey: 'settings_screen.choose_city',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: _locating ? null : _useCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_locating)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    const Icon(
                      Icons.my_location_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      _locating
                          ? 'settings_screen.locating'.tr()
                          : 'settings_screen.use_current_location'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  if (settings.cityId == null && !_locating)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDanger,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...kPresetCities.map((city) {
            final selected = settings.cityId == city.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () async {
                  await ref.read(prayerSettingsProvider.notifier).setCity(city);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryTint
                        : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'cities.${city.id}'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 18,
                        color: selected
                            ? AppColors.primary
                            : AppColors.iconMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Bottom sheet: madhab toggle plus the full list of adhan_dart's
/// calculation methods.
class _CalculationMethodSheet extends ConsumerWidget {
  const _CalculationMethodSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);

    return _SheetShell(
      titleKey: 'settings_screen.select_method',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'settings_screen.madhab'.tr(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: Madhab.values.map((madhab) {
              final selected = settings.madhab == madhab;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: madhab == Madhab.values.first ? 0 : 6,
                    right: madhab == Madhab.values.last ? 0 : 6,
                  ),
                  child: GestureDetector(
                    onTap: () => notifier.setMadhab(madhab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'madhab_names.${madhab.name}'.tr(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...CalculationMethod.values.map((method) {
            final selected = settings.method == method;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => notifier.setMethod(method),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryTint
                        : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'calculation_methods.${method.name}'.tr(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 18,
                        color: selected
                            ? AppColors.primary
                            : AppColors.iconMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Shared bottom-sheet chrome: rounded top corners, a title, and a scroll
/// area capped to 70% of the screen height so the 14-method list doesn't
/// overflow on small devices.
class _SheetShell extends StatelessWidget {
  final String titleKey;
  final Widget child;

  const _SheetShell({required this.titleKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              titleKey.tr(),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}
