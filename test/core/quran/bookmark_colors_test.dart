import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sheikh_ahmed_app/core/prayer/prayer_providers.dart'
    show sharedPreferencesProvider;
import 'package:sheikh_ahmed_app/core/quran/bookmarks_providers.dart';

Future<ProviderContainer> _container(SharedPreferences prefs) async {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a marker saved before colours existed still opens, as green', () async {
    // The old format on a phone that is being upgraded. Discarding these
    // would quietly delete every place the reader had saved.
    SharedPreferences.setMockInitialValues({
      'quran.bookmarks': ['2:255:1700000000000', '18:10:1700000001000'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);

    final bookmarks = container.read(bookmarksProvider);
    expect(bookmarks, hasLength(2));
    expect(bookmarks.first.surahNumber, 2);
    expect(bookmarks.first.ayahNumber, 255);
    expect(bookmarks.every((b) => b.color == BookmarkColor.green), isTrue);
  });

  test('a colour survives being written and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);

    container
        .read(bookmarksProvider.notifier)
        .toggle(2, 255, color: BookmarkColor.red);

    // Read through a second container, which loads from storage rather
    // than from the notifier that just wrote it.
    final reloaded = await _container(prefs);
    final saved = reloaded.read(bookmarksProvider).single;
    expect(saved.surahNumber, 2);
    expect(saved.color, BookmarkColor.red);
  });

  test('an unknown colour name reads as green rather than failing', () async {
    // A marker written by a later version that added a fourth colour.
    SharedPreferences.setMockInitialValues({
      'quran.bookmarks': ['2:255:1700000000000:turquoise'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);

    expect(container.read(bookmarksProvider).single.color, BookmarkColor.green);
  });

  test('tapping the same colour twice removes the marker', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);
    final notifier = container.read(bookmarksProvider.notifier);

    expect(notifier.toggle(2, 255, color: BookmarkColor.amber), isTrue);
    expect(notifier.toggle(2, 255, color: BookmarkColor.amber), isFalse);
    expect(container.read(bookmarksProvider), isEmpty);
  });

  test('a different colour recolours the marker instead of deleting it', () async {
    // Moving a verse from "still working on it" to "memorised" is not a
    // request to lose the place.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);
    final notifier = container.read(bookmarksProvider.notifier);

    notifier.toggle(2, 255, color: BookmarkColor.red);
    final saved = container.read(bookmarksProvider).single.savedAt;

    expect(notifier.toggle(2, 255, color: BookmarkColor.green), isTrue);
    final after = container.read(bookmarksProvider).single;
    expect(after.color, BookmarkColor.green);
    expect(container.read(bookmarksProvider), hasLength(1));
    // The date it was first saved is kept, so the list keeps its order.
    expect(after.savedAt, saved);
  });

  test('colorOf reports the colour, and null for an unmarked verse', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);
    final notifier = container.read(bookmarksProvider.notifier);

    notifier.toggle(2, 255, color: BookmarkColor.amber);
    expect(notifier.colorOf(2, 255), BookmarkColor.amber);
    expect(notifier.colorOf(2, 254), isNull);
    expect(notifier.colorOf(3, 255), isNull);
  });

  test('a malformed stored entry is skipped, not fatal', () async {
    SharedPreferences.setMockInitialValues({
      'quran.bookmarks': ['nonsense', '2:255:1700000000000:green', '1:2'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);

    expect(container.read(bookmarksProvider), hasLength(1));
  });

  test('every colour has a label the interface can show', () {
    for (final c in BookmarkColor.values) {
      expect(c.labelKey.startsWith('quran_screen.bookmark_'), isTrue);
    }
  });
}
