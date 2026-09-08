import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;

/// One phrase the digital tasbeeh can count. These are the standard short
/// dhikr formulas people actually use beads for — deliberately a small,
/// fixed list rather than free text, since the point of a tasbeeh is to
/// tap without reading.
class TasbeehPhrase {
  final String id;
  final String textAr;

  /// The repetition this phrase is conventionally counted to, used as the
  /// initial target when it's selected (the user can still change it).
  final int defaultTarget;

  const TasbeehPhrase({
    required this.id,
    required this.textAr,
    required this.defaultTarget,
  });
}

const kTasbeehPhrases = <TasbeehPhrase>[
  TasbeehPhrase(id: 'subhanallah', textAr: 'سُبْحَانَ اللَّهِ', defaultTarget: 33),
  TasbeehPhrase(id: 'alhamdulillah', textAr: 'الْحَمْدُ لِلَّهِ', defaultTarget: 33),
  TasbeehPhrase(id: 'allahuakbar', textAr: 'اللَّهُ أَكْبَرُ', defaultTarget: 33),
  TasbeehPhrase(
    id: 'tahlil',
    textAr: 'لَا إِلَهَ إِلَّا اللَّهُ',
    defaultTarget: 100,
  ),
  TasbeehPhrase(
    id: 'istighfar',
    textAr: 'أَسْتَغْفِرُ اللَّهَ',
    defaultTarget: 100,
  ),
  TasbeehPhrase(
    id: 'salat_nabi',
    textAr: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
    defaultTarget: 100,
  ),
  TasbeehPhrase(
    id: 'hawqala',
    textAr: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    defaultTarget: 100,
  ),
  TasbeehPhrase(
    id: 'subhanallah_wabihamdih',
    textAr: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    defaultTarget: 100,
  ),
];

TasbeehPhrase findTasbeehPhrase(String id) =>
    kTasbeehPhrases.firstWhere((p) => p.id == id, orElse: () => kTasbeehPhrases.first);

class TasbeehState {
  final String phraseId;

  /// Counts are kept per phrase, so switching between them mid-session
  /// doesn't wipe a tally that's part-way to its target.
  final Map<String, int> counts;
  final int target;

  /// Every tap ever recorded, across all phrases and resets — the number
  /// that makes the screen feel like a kept record rather than a scratch
  /// counter, so it deliberately survives [reset].
  final int lifetimeTotal;

  const TasbeehState({
    required this.phraseId,
    required this.counts,
    required this.target,
    required this.lifetimeTotal,
  });

  TasbeehPhrase get phrase => findTasbeehPhrase(phraseId);
  int get count => counts[phraseId] ?? 0;
  bool get isComplete => target > 0 && count >= target;

  TasbeehState copyWith({
    String? phraseId,
    Map<String, int>? counts,
    int? target,
    int? lifetimeTotal,
  }) => TasbeehState(
    phraseId: phraseId ?? this.phraseId,
    counts: counts ?? this.counts,
    target: target ?? this.target,
    lifetimeTotal: lifetimeTotal ?? this.lifetimeTotal,
  );
}

class TasbeehRepository {
  final SharedPreferences _prefs;
  TasbeehRepository(this._prefs);

  static const _kPhrase = 'tasbeeh.phrase';
  static const _kTarget = 'tasbeeh.target';
  static const _kTotal = 'tasbeeh.total';
  static String _countKey(String phraseId) => 'tasbeeh.count.$phraseId';

  TasbeehState load() {
    final phraseId = _prefs.getString(_kPhrase) ?? kTasbeehPhrases.first.id;
    return TasbeehState(
      phraseId: phraseId,
      counts: {
        for (final p in kTasbeehPhrases) p.id: _prefs.getInt(_countKey(p.id)) ?? 0,
      },
      target: _prefs.getInt(_kTarget) ?? findTasbeehPhrase(phraseId).defaultTarget,
      lifetimeTotal: _prefs.getInt(_kTotal) ?? 0,
    );
  }

  Future<void> saveCount(String phraseId, int count) =>
      _prefs.setInt(_countKey(phraseId), count);

  Future<void> savePhrase(String phraseId) => _prefs.setString(_kPhrase, phraseId);

  Future<void> saveTarget(int target) => _prefs.setInt(_kTarget, target);

  Future<void> saveTotal(int total) => _prefs.setInt(_kTotal, total);
}

final tasbeehRepositoryProvider = Provider<TasbeehRepository>((ref) {
  return TasbeehRepository(ref.watch(sharedPreferencesProvider));
});

class TasbeehNotifier extends StateNotifier<TasbeehState> {
  final TasbeehRepository _repo;

  TasbeehNotifier(this._repo) : super(_repo.load());

  /// Counting past the target is allowed on purpose — someone doing 100
  /// tasbih shouldn't be blocked at 33 just because that was the target,
  /// and the ring simply reads as full.
  void increment() {
    final next = state.count + 1;
    final total = state.lifetimeTotal + 1;
    state = state.copyWith(
      counts: {...state.counts, state.phraseId: next},
      lifetimeTotal: total,
    );
    _repo.saveCount(state.phraseId, next);
    _repo.saveTotal(total);
  }

  /// Clears the current phrase's tally only. [TasbeehState.lifetimeTotal]
  /// is untouched — resetting the beads isn't undoing the dhikr.
  void reset() {
    state = state.copyWith(counts: {...state.counts, state.phraseId: 0});
    _repo.saveCount(state.phraseId, 0);
  }

  void selectPhrase(String phraseId) {
    state = state.copyWith(
      phraseId: phraseId,
      target: findTasbeehPhrase(phraseId).defaultTarget,
    );
    _repo.savePhrase(phraseId);
    _repo.saveTarget(state.target);
  }

  void setTarget(int target) {
    state = state.copyWith(target: target);
    _repo.saveTarget(target);
  }
}

final tasbeehProvider = StateNotifierProvider<TasbeehNotifier, TasbeehState>((
  ref,
) {
  return TasbeehNotifier(ref.watch(tasbeehRepositoryProvider));
});
