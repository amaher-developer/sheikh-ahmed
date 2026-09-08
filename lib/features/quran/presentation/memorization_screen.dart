import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/quran/quran_providers.dart';
import '../../../core/quran/quran_text_service.dart';
import '../../../core/quran/surah_meta.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'quran_screen.dart' show openReciterPicker;

/// One ayah at a time, hidden by default — the user tries to recall and
/// recite it from memory, optionally recording themselves to listen back
/// before checking, then reveals the text to confirm and moves on.
///
/// Deliberately has no automatic correctness check: comparing a recitation
/// against the reference text would need real speech recognition, which
/// for classical Quranic Arabic (distinct from spoken dialects, plus
/// tajweed) a generic engine handles poorly — a wrong "close enough" or
/// "wrong" verdict would undermine the whole exercise. Self-review (record,
/// relisten, reveal, judge for yourself) is the same pattern reputable
/// memorization apps use for exactly this reason.
class MemorizationScreen extends ConsumerStatefulWidget {
  final Surah surah;

  /// Ayah number (1-based) to start the drill at, instead of always the
  /// first — e.g. the surah reader passes in wherever the user was
  /// reading, so practice picks up from there instead of forcing a
  /// restart from the beginning every time.
  final int? startAyah;

  const MemorizationScreen({super.key, required this.surah, this.startAyah});

  @override
  ConsumerState<MemorizationScreen> createState() =>
      _MemorizationScreenState();
}

class _MemorizationScreenState extends ConsumerState<MemorizationScreen> {
  late final Future<List<Ayah>> _future;
  final _recorder = AudioRecorder();
  final _player = just_audio.AudioPlayer();

  late int _index = (widget.startAyah ?? 1) - 1;
  bool _revealed = false;
  bool _isRecording = false;
  String? _recordingPath;

  /// Populated once [_future] resolves — kept separately so the AppBar's
  /// "jump to ayah" action (outside the FutureBuilder below) knows how
  /// many ayahs it can jump between.
  List<Ayah>? _ayahs;

  @override
  void initState() {
    super.initState();
    _future = ref.read(quranTextServiceProvider).fetchSurah(widget.surah.number);
    _future.then((value) {
      if (mounted) setState(() => _ayahs = value);
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<String> _pathForAyah(int ayahNumber) async {
    final dir = await getTemporaryDirectory();
    // Overwritten on every re-record of the same ayah — nothing here needs
    // to survive past this practice session.
    return '${dir.path}/memorization_${widget.surah.number}_$ayahNumber.m4a';
  }

  Future<void> _toggleRecording(int ayahNumber) async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('memorization_screen.mic_permission_denied'.tr())),
      );
      return;
    }

    final path = await _pathForAyah(ayahNumber);
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
      _recordingPath = null;
    });
  }

  Future<void> _playRecording() async {
    final path = _recordingPath;
    if (path == null) return;
    try {
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('radio_screen.playback_error'.tr())),
      );
    }
  }

  /// Plays the reciter's recitation of the current ayah — the same
  /// per-ayah source used for "tap an ayah to play from there" in the
  /// reader (see Reciter.ayahAudioUrl) — so the user can hear it said
  /// correctly before or after trying it from memory. Reuses [_player]
  /// rather than the app's shared background audio handler: this is a
  /// short foreground-only preview, not something that needs lock-screen
  /// controls or to keep playing once the user leaves this screen.
  Future<void> _playSheikh(int ayahNumber) async {
    final reciter = ref.read(selectedReciterProvider);
    try {
      await _player.setUrl(reciter.ayahAudioUrl(widget.surah.number, ayahNumber));
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('radio_screen.playback_error'.tr())),
      );
    }
  }

  void _resetForNewAyah() {
    _player.stop();
    setState(() {
      _revealed = false;
      _recordingPath = null;
      _isRecording = false;
    });
  }

  void _goTo(int index) {
    if (_isRecording) return;
    _index = index;
    _resetForNewAyah();
  }

  /// Lets practice start from (or jump to) any ayah instead of always
  /// having to step through from the beginning — e.g. picking up a long
  /// surah partway through on a later day.
  Future<void> _showJumpToAyahDialog(int maxAyah) async {
    final controller = TextEditingController();
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('memorization_screen.jump_to_ayah'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'memorization_screen.jump_to_ayah_hint'.tr(
              namedArgs: {'max': '$maxAyah'},
            ),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('memorization_screen.cancel'.tr()),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: Text('memorization_screen.go'.tr()),
          ),
        ],
      ),
    );
    if (target == null) return;
    _goTo(target.clamp(1, maxAyah) - 1);
  }

  @override
  Widget build(BuildContext context) {
    final reciter = ref.watch(selectedReciterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          surahDisplayName(widget.surah, context.locale.languageCode == 'ar'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_ayahs != null)
            IconButton(
              icon: const Icon(Icons.pin_rounded, size: 20),
              tooltip: 'memorization_screen.jump_to_ayah'.tr(),
              onPressed: () => _showJumpToAyahDialog(_ayahs!.length),
            ),
          GestureDetector(
            onTap: () => openReciterPicker(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mic_none_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    reciter.nameKey.tr(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Ayah>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'quran_screen.load_error'.tr(),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final ayahs = snapshot.data!;
          // Clamped, not trusted as-is: widget.startAyah (from the reader's
          // current position) could in principle exceed this surah's real
          // ayah count if it was ever computed from stale data.
          if (_index < 0 || _index >= ayahs.length) {
            _index = _index.clamp(0, ayahs.length - 1);
          }
          final ayah = ayahs[_index];
          final hasRecording = _recordingPath != null;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'memorization_screen.progress'.tr(
                      namedArgs: {
                        'current': '${_index + 1}',
                        'total': '${ayahs.length}',
                      },
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / ayahs.length,
                      minHeight: 5,
                      backgroundColor: AppColors.primaryTint,
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: _revealed
                            ? Text(
                                ayah.text.trim(),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.mushaf(
                                  fontSize: 22,
                                  height: 2.0,
                                ),
                              )
                            : _HiddenAyahPlaceholder(
                                onTap: () =>
                                    setState(() => _revealed = true),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CircleActionButton(
                          icon: _isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                          color: _isRecording ? Colors.red : AppColors.primary,
                          label: (_isRecording
                                  ? 'memorization_screen.stop_recording'
                                  : 'memorization_screen.record')
                              .tr(),
                          onTap: () => _toggleRecording(ayah.numberInSurah),
                        ),
                        const SizedBox(width: 16),
                        _CircleActionButton(
                          icon: Icons.play_arrow_rounded,
                          color: hasRecording
                              ? AppColors.primary
                              : AppColors.iconMuted,
                          label: 'memorization_screen.listen'.tr(),
                          onTap: hasRecording ? _playRecording : null,
                        ),
                        const SizedBox(width: 16),
                        _CircleActionButton(
                          icon: Icons.record_voice_over_rounded,
                          color: AppColors.primary,
                          label: 'memorization_screen.listen_sheikh'.tr(),
                          onTap: () => _playSheikh(ayah.numberInSurah),
                        ),
                        const SizedBox(width: 16),
                        _CircleActionButton(
                          icon: _revealed
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.gold,
                          label: (_revealed
                                  ? 'memorization_screen.hide'
                                  : 'memorization_screen.reveal')
                              .tr(),
                          onTap: () =>
                              setState(() => _revealed = !_revealed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                          child: Text('memorization_screen.previous'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _index < ayahs.length - 1
                              ? () => _goTo(_index + 1)
                              : null,
                          child: Text('memorization_screen.next'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HiddenAyahPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _HiddenAyahPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.4),
            width: 1.5,
          ),
          color: AppColors.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              size: 28,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'memorization_screen.hidden_hint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
