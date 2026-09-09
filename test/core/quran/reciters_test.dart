import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/reciter_data.dart';

void main() {
  Map<String, dynamic> translations(String lang) =>
      jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>;

  group('the list', () {
    test('it is a real choice, not a handful', () {
      expect(kReciters.length, greaterThanOrEqualTo(20));
    });

    test('no two share an id', () {
      // The chosen reciter is stored by id, so a collision would silently
      // switch someone to a different voice.
      final ids = kReciters.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('no two share a server or an everyayah folder', () {
      // Two entries pointing at the same audio are the same reciter listed
      // twice — a duplicate in the picker with two different names.
      final servers = kReciters.map((r) => r.server).toList();
      expect(servers.toSet().length, servers.length);
      final folders = kReciters.map((r) => r.everyAyahFolder).toList();
      expect(folders.toSet().length, folders.length);
    });

    test('the default is still al-Afasy', () {
      // Changing it would move every existing user to another voice on
      // update, since the stored id is only consulted when one was chosen.
      expect(kDefaultReciter.id, 'afs');
      expect(findReciter(null).id, 'afs');
      expect(findReciter('nonexistent').id, 'afs');
      expect(findReciter('maher').id, 'maher');
    });
  });

  group('every entry is complete', () {
    test('the surah server is an https folder URL ending in a slash', () {
      // audioUrl just appends "001.mp3"; a missing slash silently produces
      // ".../maher001.mp3", which 404s on every surah.
      for (final r in kReciters) {
        expect(r.server.startsWith('https://'), isTrue, reason: r.id);
        expect(r.server.endsWith('/'), isTrue, reason: r.id);
      }
    });

    test('both URL shapes come out right', () {
      final maher = findReciter('maher');
      expect(
        maher.audioUrl(1),
        'https://server12.mp3quran.net/maher/001.mp3',
      );
      expect(
        maher.audioUrl(114),
        'https://server12.mp3quran.net/maher/114.mp3',
      );
      expect(
        maher.ayahAudioUrl(2, 255),
        'https://everyayah.com/data/MaherAlMuaiqly128kbps/002255.mp3',
      );
    });

    test('every reciter has an everyayah folder', () {
      // Without one, "play from this ayah" is silent for that voice while
      // whole-surah playback works — a failure nobody would report clearly.
      for (final r in kReciters) {
        expect(r.everyAyahFolder, isNotEmpty, reason: r.id);
        expect(r.everyAyahFolder.contains('/'), isFalse, reason: r.id);
      }
    });

    test('every name resolves in both languages', () {
      for (final lang in ['ar', 'en']) {
        final names = translations(lang)['reciters'] as Map<String, dynamic>;
        for (final r in kReciters) {
          final key = r.nameKey.split('.').last;
          expect(key, r.id, reason: 'nameKey should follow the id');
          expect(names[key], isNotNull, reason: '$lang ${r.nameKey}');
          expect(
            (names[key] as String).trim(),
            isNotEmpty,
            reason: '$lang ${r.nameKey}',
          );
        }
      }
    });
  });

  test('the picker can scroll', () {
    // Twenty-one rows do not fit a Column that sizes to its children: the
    // sheet ran off the bottom of the screen and the last reciters were
    // unreachable. It is now capped and scrollable inside the cap.
    final screen = File(
      'lib/features/quran/presentation/quran_screen.dart',
    ).readAsStringSync();
    final sheet = screen.substring(
      screen.indexOf('class ReciterSheet'),
      screen.indexOf('/// Small animated equalizer bars'),
    );

    expect(sheet.contains('ConstrainedBox'), isTrue);
    expect(sheet.contains('maxHeight'), isTrue);
    expect(sheet.contains('ListView('), isTrue);
    // The spread that could not scroll.
    expect(sheet.contains('...kReciters.map'), isFalse);
  });
}
