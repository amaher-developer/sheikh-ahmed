import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/audio_download_service.dart';
import 'package:sheikh_ahmed_app/core/quran/bulk_download_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/reciter_data.dart';

void main() {
  final reciter = kReciters.first;
  final other = kReciters.length > 1 ? kReciters[1] : kReciters.first;

  test('counts only the selected reciter\'s downloads', () {
    // Downloads are per (reciter, surah), so a surah downloaded for one
    // reciter must not count toward another's total — otherwise the card
    // would claim the Quran is offline when that voice has none of it.
    final downloaded = {
      '${reciter.id}:1',
      '${reciter.id}:2',
      '${other.id}:3',
      '${other.id}:4',
      '${other.id}:5',
    };

    expect(downloadedCountFor(downloaded, reciter), 2);
    if (other.id != reciter.id) {
      expect(downloadedCountFor(downloaded, other), 3);
    }
  });

  test('an id that merely starts the same is not miscounted', () {
    // A guard on the prefix match: "abc:1" must not be counted for a
    // reciter whose id is "ab".
    final downloaded = {'${reciter.id}x:1', '${reciter.id}:7'};
    expect(downloadedCountFor(downloaded, reciter), 1);
  });

  test('nothing downloaded counts as zero, not as an error', () {
    expect(downloadedCountFor(<String>{}, reciter), 0);
  });

  group('BulkDownloadState', () {
    test('reports progress as a fraction of this run', () {
      const state = BulkDownloadState(running: true, completed: 57, total: 114);
      expect(state.progress, closeTo(0.5, 0.001));
    });

    test('an empty run reports zero rather than dividing by zero', () {
      const state = BulkDownloadState();
      expect(state.progress, 0);
    });

    test('progress never exceeds 1', () {
      const state = BulkDownloadState(completed: 200, total: 114);
      expect(state.progress, 1);
    });

    test('clearCurrent drops the surah label when the run ends', () {
      const running = BulkDownloadState(
        running: true,
        currentSurah: 18,
        total: 5,
      );
      final done = running.copyWith(running: false, clearCurrent: true);
      expect(done.currentSurah, isNull);
      // The counters survive, so the card can still show the outcome.
      expect(done.total, 5);
    });
  });

  group('TextDownloadState', () {
    test('reports progress as a fraction of the 114 surahs', () {
      const state = TextDownloadState(running: true, completed: 57, total: 114);
      expect(state.progress, closeTo(0.5, 0.001));
    });

    test('an untouched run reports zero rather than dividing by zero', () {
      expect(const TextDownloadState().progress, 0);
    });

    test('failures are counted without ending the run', () {
      // The run keeps going past a failure, so completed + failures is what
      // accounts for every surah attempted.
      const state = TextDownloadState(completed: 110, failures: 4, total: 114);
      expect(state.completed + state.failures, state.total);
    });
  });

  group('DownloadCancelToken', () {
    test('cancel runs the registered aborts', () {
      // The listener is what closes the HTTP client; without it cancelling
      // only stops the queue and the current transfer runs to completion.
      var aborted = 0;
      final token = DownloadCancelToken()
        ..onCancel(() => aborted++)
        ..onCancel(() => aborted++);
      expect(token.isCancelled, isFalse);
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(aborted, 2);
    });

    test('cancel is idempotent', () {
      var aborted = 0;
      final token = DownloadCancelToken()..onCancel(() => aborted++);
      token.cancel();
      token.cancel();
      expect(aborted, 1);
    });

    test('registering after cancel fires immediately', () {
      // A token can be cancelled between two awaits, before the next download
      // registers its client. Firing late-registered listeners at once is
      // what stops that download from starting a transfer nobody wants.
      final token = DownloadCancelToken()..cancel();
      var aborted = false;
      token.onCancel(() => aborted = true);
      expect(aborted, isTrue);
    });
  });
}
