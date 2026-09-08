import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// Prefixed: easy_localization re-exports intl, whose TextDirection shadows
// Flutter's enum of the same name.
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/quran/surah_meta.dart';
import '../../../core/quran/word_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_numerals.dart';

/// Plays one verse a word at a time, highlighting the word being said.
///
/// This is the drill people actually use to memorise: hear a word, repeat
/// it, move on — not the whole verse at reciter's pace. Tapping any word
/// replays just that one, which is what makes it usable for the word that
/// will not stick.
void showWordByWord({
  required BuildContext context,
  required Surah surah,
  required int ayahNumber,
}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WordByWordSheet(surah: surah, ayahNumber: ayahNumber),
  );
}

class WordByWordSheet extends ConsumerStatefulWidget {
  final Surah surah;
  final int ayahNumber;

  const WordByWordSheet({
    super.key,
    required this.surah,
    required this.ayahNumber,
  });

  @override
  ConsumerState<WordByWordSheet> createState() => _WordByWordSheetState();
}

class _WordByWordSheetState extends ConsumerState<WordByWordSheet> {
  /// Its own player, not the app's audio handler.
  ///
  /// The handler owns the surah recitation, with a notification and a
  /// lockscreen entry: routing half-second word clips through it would
  /// replace whatever the reader had playing and leave a media
  /// notification advertising a single word.
  final _player = AudioPlayer();

  /// Which word is sounding, or null between clips.
  int? _playing;

  /// True while walking the whole verse, so the button offers "stop".
  bool _walking = false;

  /// Cancels a walk in progress. Without it, closing the sheet mid-walk
  /// left the loop scheduling the next word against a dead player.
  bool _cancelled = false;

  @override
  void dispose() {
    _cancelled = true;
    _player.dispose();
    super.dispose();
  }

  Future<void> _playOne(SpokenWord word, int index) async {
    final url = word.audioUrl;
    if (url == null) return;
    setState(() => _playing = index);
    try {
      await _player.setUrl(url);
      await _player.play();
      // Waits for the clip itself rather than a guessed duration: the words
      // differ enough in length that a fixed delay either clipped the long
      // ones or left silence after the short ones.
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed,
      );
    } catch (_) {
      // A clip that will not load stops this word, not the whole drill.
    }
    if (mounted && _playing == index) setState(() => _playing = null);
  }

  Future<void> _walk(List<SpokenWord> words) async {
    if (_walking) {
      _cancelled = true;
      await _player.stop();
      if (mounted) setState(() { _walking = false; _playing = null; });
      return;
    }

    _cancelled = false;
    setState(() => _walking = true);
    for (var i = 0; i < words.length; i++) {
      if (_cancelled || !mounted) break;
      await _playOne(words[i], i);
      if (_cancelled || !mounted) break;
      // A beat between words: the pause is what gives the learner room to
      // repeat the one they just heard.
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (mounted) setState(() { _walking = false; _playing = null; });
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    final verseKey = '${widget.surah.number}:${widget.ayahNumber}';
    final words = ref.watch(wordAudioProvider(verseKey));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                'quran_screen.word_by_word_of'.tr(namedArgs: {
                  'surah': surahDisplayName(widget.surah, arabic),
                  'ayah': arabic
                      ? toArabicDigits('${widget.ayahNumber}')
                      : '${widget.ayahNumber}',
                }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: words.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'quran_screen.word_by_word_error'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                data: (list) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Directionality(
                    textDirection: material.TextDirection.rtl,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, w) in list.indexed)
                          _WordChip(
                            word: w,
                            active: _playing == i,
                            onTap: w.audioUrl == null
                                ? null
                                : () {
                                    _cancelled = true;
                                    _playOne(w, i);
                                  },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: words.hasValue
                        ? () => _walk(words.requireValue)
                        : null,
                    icon: Icon(
                      _walking
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(
                      (_walking
                              ? 'quran_screen.word_by_word_stop'
                              : 'quran_screen.word_by_word_play')
                          .tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final SpokenWord word;
  final bool active;
  final VoidCallback? onTap;

  const _WordChip({
    required this.word,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          word.text,
          textScaler: TextScaler.noScaling,
          style: AppTextStyles.mushaf(fontSize: 20, height: 1.7).copyWith(
            color: active
                ? Colors.white
                // A word with no clip is drawn muted, so its silence when
                // tapped reads as "there is no recording" rather than as a
                // broken chip.
                : (word.audioUrl == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
