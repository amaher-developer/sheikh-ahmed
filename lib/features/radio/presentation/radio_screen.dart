import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/audio/quran_stations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _eq;

  @override
  void initState() {
    super.initState();
    _eq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('radio_screen.playback_error'.tr())));
  }

  MediaItem _itemFor(QuranStation station) => MediaItem(
    id: station.url,
    title: station.nameKey.tr(),
    artist: station.subtitleKey.tr(),
  );

  Future<void> _toggleStation(QuranStation station) async {
    try {
      // Live radio streams don't send a "completed" event, but clear any
      // leftover Quran auto-advance/skip callbacks anyway — belt and
      // suspenders (also drops the notification's now-meaningless
      // prev/next buttons — see QuranAudioHandler._transformEvent).
      final handler = ref.read(audioHandlerProvider);
      handler.nextItemResolver = null;
      handler.previousItemResolver = null;
      await toggleAudio(ref, _itemFor(station));
    } catch (_) {
      _showError();
    }
  }

  Future<void> _skip(int delta, int currentIndex) async {
    final next = (currentIndex + delta) % kQuranStations.length;
    final index = next < 0 ? next + kQuranStations.length : next;
    try {
      final handler = ref.read(audioHandlerProvider);
      handler.nextItemResolver = null;
      handler.previousItemResolver = null;
      await playMediaItem(ref, _itemFor(kQuranStations[index]));
    } catch (_) {
      _showError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowUrl = ref.watch(currentMediaItemProvider).valueOrNull?.id;
    final playbackStateAsync = ref.watch(playbackStateProvider);
    final playerState = playbackStateAsync.valueOrNull;
    final isPlaying = playerState?.playing ?? false;
    final isBuffering =
        playerState?.processingState == AudioProcessingState.loading ||
        playerState?.processingState == AudioProcessingState.buffering;

    var selectedIndex = kQuranStations.indexWhere((s) => s.url == nowUrl);
    if (selectedIndex == -1) selectedIndex = 0;
    final displayStation = kQuranStations[selectedIndex];
    final displayIsActive = nowUrl == displayStation.url;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SubScreenHeader(
            bottomPadding: 62,
            child: SubScreenTitleRow(
              title: 'radio_screen.title'.tr(),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BlinkDot(active: displayIsActive && isPlaying),
                    const SizedBox(width: 6),
                    Text(
                      'radio_screen.live'.tr(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NowPlayingCard(
                  station: displayStation,
                  playing: displayIsActive && isPlaying,
                  buffering: displayIsActive && isBuffering,
                  eq: _eq,
                  onToggle: () => _toggleStation(displayStation),
                  onNext: () => _skip(1, selectedIndex),
                  onPrevious: () => _skip(-1, selectedIndex),
                ),
                const OrnamentDivider(),
                Text(
                  'radio_screen.available_stations'.tr(),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(kQuranStations.length, (i) {
                  final station = kQuranStations[i];
                  final on = station.url == nowUrl;
                  final showPause = on && isPlaying;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _toggleStation(station),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: on ? AppColors.primaryTint : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: on
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(
                                      alpha: 0.05,
                                    ),
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
                                color: on
                                    ? AppColors.primary
                                    : AppColors.chipBg,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.podcasts_rounded,
                                size: 18,
                                color: on ? Colors.white : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    station.nameKey.tr(),
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
                                    station.subtitleKey.tr(),
                                    maxLines: 1,
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
                            if (on && isBuffering)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.gold,
                                ),
                              )
                            else
                              Icon(
                                showPause
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 19,
                                color: AppColors.gold,
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
        ),
      ],
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final QuranStation station;
  final bool playing;
  final bool buffering;
  final AnimationController eq;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const _NowPlayingCard({
    required this.station,
    required this.playing,
    required this.buffering,
    required this.eq,
    required this.onToggle,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 98,
            height: 98,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/sheikh_avatar.png',
              fit: BoxFit.cover,
              // Decoded at ~2x the 98px display size, not the source's
              // full 480px.
              cacheWidth: 200,
              cacheHeight: 200,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            station.nameKey.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            buffering
                ? 'radio_screen.buffering'.tr()
                : station.subtitleKey.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 24,
            child: AnimatedBuilder(
              animation: eq,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(9, (i) {
                  final phase = (eq.value + i * 0.12) % 1.0;
                  final h = playing ? 5 + phase * 17 : 5.0;
                  return Container(
                    width: 3,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onNext,
                child: Icon(
                  Icons.skip_next_rounded,
                  size: 24,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: buffering
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: onPrevious,
                child: Icon(
                  Icons.skip_previous_rounded,
                  size: 24,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlinkDot extends StatefulWidget {
  final bool active;
  const _BlinkDot({required this.active});

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_c),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.active
              ? const Color(0xFF8FE0A0)
              : Colors.white.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
