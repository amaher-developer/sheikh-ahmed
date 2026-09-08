import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/quran/bookmarks_providers.dart';

void main() {
  late BookmarksRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BookmarksRepository(await SharedPreferences.getInstance());
  });

  test('starts empty', () {
    expect(repo.load(), isEmpty);
  });

  test('notifier toggle adds then removes a bookmark', () {
    final notifier = BookmarksNotifier(repo);

    expect(notifier.isBookmarked(2, 255), isFalse);

    final added = notifier.toggle(2, 255);
    expect(added, isTrue);
    expect(notifier.isBookmarked(2, 255), isTrue);
    expect(notifier.state, hasLength(1));

    final removed = notifier.toggle(2, 255);
    expect(removed, isFalse);
    expect(notifier.isBookmarked(2, 255), isFalse);
    expect(notifier.state, isEmpty);
  });

  test('persists across repository instances backed by the same prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repoA = BookmarksRepository(prefs);
    final notifierA = BookmarksNotifier(repoA);

    notifierA.toggle(2, 255);
    notifierA.toggle(36, 1);

    final repoB = BookmarksRepository(prefs);
    final reloaded = repoB.load();
    expect(reloaded, hasLength(2));
    expect(
      reloaded.map((b) => (b.surahNumber, b.ayahNumber)),
      containsAll([(2, 255), (36, 1)]),
    );
  });

  test('remove() deletes a specific bookmark without touching others', () {
    final notifier = BookmarksNotifier(repo);
    notifier.toggle(2, 255);
    notifier.toggle(36, 1);

    notifier.remove(2, 255);

    expect(notifier.isBookmarked(2, 255), isFalse);
    expect(notifier.isBookmarked(36, 1), isTrue);
  });
}
