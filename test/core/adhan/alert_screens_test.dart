import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String get _manifest =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

String _kotlin(String name) => File(
  'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/$name',
).readAsStringSync();

String _layout(String name) =>
    File('android/app/src/main/res/layout/$name').readAsStringSync();

/// The chunk of manifest declaring one component.
String _block(String name) {
  final manifest = _manifest;
  final start = manifest.indexOf('android:name=".$name"');
  expect(start, greaterThan(0), reason: '$name is not in the manifest');
  return manifest.substring(start, manifest.indexOf('/>', start));
}

void main() {
  group('the alert screens are not reachable from outside the app', () {
    // They were exported briefly to photograph them on a device — the shell
    // cannot start a non-exported activity — and shipping them that way
    // would let any app on the phone throw a full-screen prayer alert.
    for (final activity in ['AdhanAlertActivity', 'ZikrAlertActivity']) {
      test('$activity is not exported', () {
        expect(
          _block(activity).contains('android:exported="false"'),
          isTrue,
          reason: activity,
        );
        expect(
          _block(activity).contains('android:exported="true"'),
          isFalse,
          reason: activity,
        );
      });
    }

    test('neither alert receiver is exported either', () {
      for (final receiver in ['AdhanAlarmReceiver', 'ZikrAlarmReceiver']) {
        expect(
          _block(receiver).contains('android:exported="false"'),
          isTrue,
          reason: receiver,
        );
      }
    });
  });

  group('the views and the code agree', () {
    // A findViewById cast that does not match the layout throws on launch,
    // and because these screens are opened by a receiver the crash shows as
    // the adhan simply not appearing — no error, nothing on screen. It cost
    // a build to find, so it is pinned here.
    test('the adhan controls are read as the type the layout declares', () {
      final layout = _layout('activity_adhan_alert.xml');
      final code = _kotlin('AdhanAlertActivity.kt');

      // Styled TextViews, so they can carry the app's pill backgrounds and
      // font rather than the platform button look.
      expect(layout.contains('<Button'), isFalse);
      expect(code.contains('findViewById<android.widget.Button>'), isFalse);
      for (final id in ['adhan_title', 'adhan_body', 'adhan_stop',
          'adhan_dismiss', 'adhan_time']) {
        expect(layout.contains('@+id/$id'), isTrue, reason: id);
        expect(code.contains('R.id.$id'), isTrue, reason: id);
      }
    });

    test('every id the dhikr card reads exists in its layout', () {
      final layout = _layout('activity_zikr_alert.xml');
      final code = _kotlin('ZikrAlertActivity.kt');
      for (final id in ['zikr_card', 'zikr_text']) {
        expect(layout.contains('@+id/$id'), isTrue, reason: id);
        expect(code.contains('R.id.$id'), isTrue, reason: id);
      }
    });
  });

  group('how each screen behaves', () {
    test('the dhikr card goes away on its own', () {
      // A dhikr is a nudge, not an alarm. One that waits to be dismissed,
      // several times a day, is a feature people switch off.
      final code = _kotlin('ZikrAlertActivity.kt');
      expect(code.contains('postDelayed(close, VISIBLE_MS)'), isTrue);
      expect(code.contains('VISIBLE_MS = 7000L'), isTrue);
    });

    test('the dhikr card lets touches through to what is underneath', () {
      final code = _kotlin('ZikrAlertActivity.kt');
      expect(code.contains('FLAG_NOT_TOUCH_MODAL'), isTrue);

      // And its window is transparent, or the card would arrive on a black
      // screen instead of over whatever the phone was doing.
      final styles = File(
        'android/app/src/main/res/values/styles.xml',
      ).readAsStringSync();
      expect(styles.contains('ZikrAlertTheme'), isTrue);
      expect(styles.contains('windowIsTranslucent">true'), isTrue);
      expect(styles.contains('backgroundDimEnabled">false'), isTrue);
    });

    test('the adhan screen does not dismiss itself', () {
      // The opposite choice, deliberately: it stays until it is answered.
      final code = _kotlin('AdhanAlertActivity.kt');
      expect(code.contains('postDelayed'), isFalse);
      expect(code.contains('FLAG_KEEP_SCREEN_ON'), isTrue);
    });

    test('the time on the adhan screen is in Arabic-Indic digits', () {
      // The system formatter follows the phone's locale, which on most of
      // these devices is English — so the one number on an otherwise Arabic
      // screen came out in Latin figures.
      final code = _kotlin('AdhanAlertActivity.kt');
      expect(code.contains('toArabicDigits('), isTrue);
    });
  });
}
