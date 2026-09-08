import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'reciter_data.dart';

/// Downloads and manages locally-stored surah audio, so a surah can be
/// played with no connection once it's been downloaded once — the same
/// "download for offline" pattern as YouTube's per-video download button,
/// applied per (reciter, surah).
class AudioDownloadService {
  const AudioDownloadService();

  static String buildPath(String docsPath, String reciterId, int surahNumber) =>
      '$docsPath/quran_audio/$reciterId/$surahNumber.mp3';

  Future<String> docsPath() async =>
      (await getApplicationDocumentsDirectory()).path;

  Future<File> _file(Reciter reciter, int surahNumber) async =>
      File(buildPath(await docsPath(), reciter.id, surahNumber));

  Future<bool> isDownloaded(Reciter reciter, int surahNumber) async =>
      (await _file(reciter, surahNumber)).exists();

  /// Every downloaded (reciterId, surahNumber) pair, as "reciterId:n" keys
  /// — read once at startup so playback can synchronously prefer a local
  /// file (see DownloadedSurahsNotifier) instead of an async filesystem
  /// check on every tap.
  Future<Set<String>> scanDownloaded() async {
    final root = Directory('${await docsPath()}/quran_audio');
    if (!await root.exists()) return {};
    final keys = <String>{};
    await for (final reciterDir in root.list()) {
      if (reciterDir is! Directory) continue;
      final reciterId = reciterDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      await for (final entity in reciterDir.list()) {
        if (entity is! File || !entity.path.endsWith('.mp3')) continue;
        final name = entity.uri.pathSegments.last;
        final surahNumber = int.tryParse(name.replaceAll('.mp3', ''));
        if (surahNumber != null) keys.add('$reciterId:$surahNumber');
      }
    }
    return keys;
  }

  /// Downloads [surahNumber]'s audio for [reciter], reporting 0..1
  /// progress. Written to a `.part` file and renamed only on success, so a
  /// cancelled or failed download never leaves a corrupt file that
  /// [isDownloaded] would wrongly treat as complete.
  Future<void> download(
    Reciter reciter,
    int surahNumber, {
    void Function(double progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final target = await _file(reciter, surahNumber);
    await target.parent.create(recursive: true);
    final partFile = File('${target.path}.part');

    // Resume from whatever an earlier attempt already fetched.
    //
    // Al-Baqara is ~115 MB for some reciters. The old code deleted the .part
    // file whenever a download stopped, so every cancel threw away the whole
    // transfer and the next attempt began again at zero — on a connection
    // that drops, or for someone who stops and resumes, it could never
    // finish however many times they tried. mp3quran's servers advertise
    // Accept-Ranges: bytes and answer 206, so picking up where we left off
    // just works.
    var existing = await partFile.exists() ? await partFile.length() : 0;

    final request = http.Request(
      'GET',
      Uri.parse(reciter.audioUrl(surahNumber)),
    );
    if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
    // Held in a variable and closed in the finally below. The old code called
    // http.Client() inline and never closed it, leaking a connection per
    // surah — 114 of them on a full download.
    final client = http.Client();
    // Closing the client mid-stream is what actually aborts a transfer.
    // Checking a flag between chunks is not enough on its own, but checking
    // it is what tells the difference between an abort and a real failure.
    cancelToken?.onCancel(client.close);

    try {
      final http.StreamedResponse response;
      try {
        response = await client.send(request);
      } catch (_) {
        throw cancelToken?.isCancelled ?? false
            ? DownloadCancelledException()
            : AudioDownloadException();
      }
      final bool append;
      if (response.statusCode == 206) {
        append = existing > 0;
      } else if (response.statusCode == 200) {
        // The server ignored the Range header, so it is sending the file from
        // the start and anything already on disk is stale.
        existing = 0;
        append = false;
      } else {
        // 416 means the .part is at least as long as the file itself, so it
        // cannot be a valid prefix of it — drop it rather than resume from a
        // position that will never complete.
        if (response.statusCode == 416 && await partFile.exists()) {
          await partFile.delete();
        }
        throw AudioDownloadException();
      }

      // contentLength on a 206 is the length of *this* slice, not the file.
      final total = existing + (response.contentLength ?? 0);
      var received = existing;
      final sink = partFile.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      var failed = false;
      try {
        await for (final chunk in response.stream) {
          if (cancelToken?.isCancelled ?? false) {
            throw DownloadCancelledException();
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await sink.flush();
      } catch (_) {
        failed = true;
      } finally {
        // Closed exactly once, on every path. The .part file is deliberately
        // left behind: it is what the next attempt resumes from, and it can
        // never be mistaken for a finished download because isDownloaded only
        // ever looks at the final name.
        await sink.close();
      }
      if (failed) {
        throw cancelToken?.isCancelled ?? false
            ? DownloadCancelledException()
            : AudioDownloadException();
      }

      // Renamed only when the file is genuinely whole. Without this check a
      // connection that died mid-stream would still be promoted to a finished
      // download, and the surah would simply stop playing half way through
      // with nothing to explain why.
      if (total > 0 && await partFile.length() != total) {
        throw AudioDownloadException();
      }
      await partFile.rename(target.path);
    } finally {
      client.close();
    }
  }

  Future<void> delete(Reciter reciter, int surahNumber) async {
    final file = await _file(reciter, surahNumber);
    if (await file.exists()) await file.delete();
  }
}

class AudioDownloadException implements Exception {}

/// Thrown when a download stopped because the user asked it to.
///
/// Distinct from [AudioDownloadException] so a cancelled surah is not counted
/// as a failure and reported back as "3 surahs need retrying".
class DownloadCancelledException implements Exception {}

/// Lets an in-flight download be aborted.
///
/// Needed because awaiting a download is not interruptible on its own: a flag
/// checked between surahs leaves the current one running to completion, and a
/// long surah is tens of megabytes. Cancelling looked like it did nothing and
/// the screen sat there apparently frozen until the file finished.
class DownloadCancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    // Copied before iterating: a listener closing an HTTP client can complete
    // a stream synchronously, which re-enters this class.
    for (final listener in [..._listeners]) {
      listener();
    }
    _listeners.clear();
  }

  /// Runs [fn] on cancel, or immediately if cancellation already happened —
  /// otherwise a token cancelled between two awaits would never fire.
  void onCancel(void Function() fn) {
    if (_cancelled) {
      fn();
      return;
    }
    _listeners.add(fn);
  }
}
