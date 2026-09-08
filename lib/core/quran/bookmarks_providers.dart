import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;

/// What a marker is for.
///
/// Three colours rather than a free palette, because the point is sorting
/// at a glance: a page of markers in twelve shades says nothing. These are
/// the three states anyone memorising actually tracks — done, working on
/// it, and the one that will not stick.
enum BookmarkColor {
  green('quran_screen.bookmark_memorised', Color(0xFF2F7D4F)),
  amber('quran_screen.bookmark_reviewing', Color(0xFFC98A17)),
  red('quran_screen.bookmark_difficult', Color(0xFFB3261E));

  final String labelKey;
  final Color color;

  const BookmarkColor(this.labelKey, this.color);
}

/// A saved ayah to return to later — the "علامة" (bookmark) feature.
class AyahBookmark {
  final int surahNumber;
  final int ayahNumber;
  final DateTime savedAt;
  final BookmarkColor color;

  const AyahBookmark({
    required this.surahNumber,
    required this.ayahNumber,
    required this.savedAt,
    this.color = BookmarkColor.green,
  });

  String _encode() =>
      '$surahNumber:$ayahNumber:${savedAt.millisecondsSinceEpoch}:${color.name}';

  static AyahBookmark? _decode(String raw) {
    final parts = raw.split(':');
    // Three parts is the original format, from before markers had colours.
    // Those entries are already on people's phones, so they are read as
    // green rather than discarded — a reader who upgrades must not lose
    // the places they saved.
    if (parts.length < 3) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    final millis = int.tryParse(parts[2]);
    if (surah == null || ayah == null || millis == null) return null;
    return AyahBookmark(
      surahNumber: surah,
      ayahNumber: ayah,
      savedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      color: parts.length > 3
          ? BookmarkColor.values.firstWhere(
              (c) => c.name == parts[3],
              orElse: () => BookmarkColor.green,
            )
          : BookmarkColor.green,
    );
  }
}

class BookmarksRepository {
  final SharedPreferences _prefs;
  BookmarksRepository(this._prefs);

  static const _kKey = 'quran.bookmarks';

  List<AyahBookmark> load() {
    final raw = _prefs.getStringList(_kKey) ?? const [];
    return raw
        .map(AyahBookmark._decode)
        .whereType<AyahBookmark>()
        .toList();
  }

  Future<void> save(List<AyahBookmark> bookmarks) =>
      _prefs.setStringList(_kKey, bookmarks.map((b) => b._encode()).toList());
}

final bookmarksRepositoryProvider = Provider<BookmarksRepository>((ref) {
  return BookmarksRepository(ref.watch(sharedPreferencesProvider));
});

class BookmarksNotifier extends StateNotifier<List<AyahBookmark>> {
  final BookmarksRepository _repo;

  BookmarksNotifier(this._repo) : super(_repo.load());

  bool isBookmarked(int surahNumber, int ayahNumber) =>
      state.any((b) => b.surahNumber == surahNumber && b.ayahNumber == ayahNumber);

  /// The colour this ayah is marked in, or null if it is not marked.
  BookmarkColor? colorOf(int surahNumber, int ayahNumber) {
    for (final b in state) {
      if (b.surahNumber == surahNumber && b.ayahNumber == ayahNumber) {
        return b.color;
      }
    }
    return null;
  }

  /// Returns true if the ayah ended up bookmarked, false if it was removed.
  ///
  /// Toggling with a [color] that differs from the one already saved
  /// recolours the marker instead of removing it: a reader moving a verse
  /// from "still working on it" to "memorised" is not asking to lose it.
  bool toggle(
    int surahNumber,
    int ayahNumber, {
    BookmarkColor color = BookmarkColor.green,
  }) {
    final existingIndex = state.indexWhere(
      (b) => b.surahNumber == surahNumber && b.ayahNumber == ayahNumber,
    );
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      if (existing.color != color) {
        state = [...state]..[existingIndex] = AyahBookmark(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          savedAt: existing.savedAt,
          color: color,
        );
        _repo.save(state);
        return true;
      }
      state = [...state]..removeAt(existingIndex);
      _repo.save(state);
      return false;
    }
    state = [
      ...state,
      AyahBookmark(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        savedAt: DateTime.now(),
        color: color,
      ),
    ];
    _repo.save(state);
    return true;
  }

  void remove(int surahNumber, int ayahNumber) {
    state = state
        .where((b) => !(b.surahNumber == surahNumber && b.ayahNumber == ayahNumber))
        .toList();
    _repo.save(state);
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<AyahBookmark>>((ref) {
      return BookmarksNotifier(ref.watch(bookmarksRepositoryProvider));
    });
