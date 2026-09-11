import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps downloaded content out of the user's iCloud backup.
///
/// Surah audio and the printed Mus'haf's page fonts and layouts are stored
/// under the app's Documents directory, which iOS backs up by default. All of
/// it can simply be downloaded again, and a whole Mus'haf plus a reciter or
/// two runs to hundreds of megabytes of someone's iCloud storage — Apple's
/// data storage guidelines ask for exactly this kind of content to be marked
/// as not backed up. Marking a directory covers everything inside it,
/// including files added later.
///
/// iOS only; the native half is in ios/Runner/AppDelegate.swift.
class BackupExclusion {
  const BackupExclusion._();

  static const _channel = MethodChannel('com.manassa.sheikhahmed/storage');

  /// Directories already marked in this process. Callers resolve their
  /// directory on every file lookup, and the flag only needs setting once.
  static final Set<String> _marked = {};

  /// Marks [dir], which must already exist, as excluded from backup.
  static Future<void> excludeDirectory(Directory dir) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!_marked.add(dir.path)) return;
    try {
      await _channel.invokeMethod<bool>('excludeFromBackup', {
        'path': dir.path,
      });
    } on PlatformException {
      // Left unmarked so the next lookup tries again. Never worth failing a
      // download or a page load over.
      _marked.remove(dir.path);
    } on MissingPluginException {
      _marked.remove(dir.path);
    }
  }
}
