import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('does not declare USE_EXACT_ALARM', () {
    // Google Play restricts USE_EXACT_ALARM to apps whose core functionality
    // is an alarm clock or a calendar. This app is a prayer companion, so
    // declaring it forces a false answer on the Play Console "Exact alarms"
    // form — which blocks the release and can get the listing suspended.
    // The permission is easy to re-add by reflex when reminders arrive late;
    // this is here to make that fail loudly at test time instead of at
    // submission time.
    expect(
      manifest.contains('android.permission.USE_EXACT_ALARM'),
      isFalse,
      reason: 'USE_EXACT_ALARM is not permitted for this app category',
    );
  });

  test('still declares SCHEDULE_EXACT_ALARM', () {
    // The unrestricted alternative, and the only thing keeping the adhan on
    // time. Dropping both would silently downgrade every reminder to an
    // inexact alarm that Doze can defer for hours.
    expect(
      manifest.contains('android.permission.SCHEDULE_EXACT_ALARM'),
      isTrue,
    );
  });
}
