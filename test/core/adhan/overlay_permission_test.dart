import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sheikh_ahmed_app/core/adhan/overlay_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.manassa.sheikhahmed/widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers the channel with [reply], recording what was asked.
  List<String> stub(Object? Function(String method) reply) {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return reply(call.method);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  test('it reads the real state from the platform', () async {
    stub((_) => false);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(overlayPermissionProvider);
    await container.read(overlayPermissionProvider.notifier).refresh();

    expect(container.read(overlayPermissionProvider), isFalse);
  });

  test('a platform that cannot answer counts as allowed', () async {
    // The same rule the exact-alarm permission follows. Being unable to
    // *ask* is not evidence the permission is missing, and guessing the
    // other way puts a prompt in front of people with nothing to fix.
    stub((_) => throw MissingPluginException());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(overlayPermissionProvider.notifier).refresh();

    expect(container.read(overlayPermissionProvider), isTrue);
  });

  test('a null answer counts as allowed too', () async {
    stub((_) => null);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(overlayPermissionProvider.notifier).refresh();

    expect(container.read(overlayPermissionProvider), isTrue);
  });

  test('requesting asks the platform to open the settings screen', () async {
    final calls = stub((method) => method == 'canDrawOverlays' ? false : true);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final opened = await container
        .read(overlayPermissionProvider.notifier)
        .request();

    expect(opened, isTrue);
    expect(calls, contains('requestOverlayPermission'));
  });

  test('a device with no such screen reports that, rather than pretending',
      () async {
    // Some manufacturers ship no overlay screen at all. The row must be
    // able to tell "asked" from "there was nothing to ask".
    stub((method) => method == 'requestOverlayPermission' ? false : false);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(overlayPermissionProvider.notifier).request(),
      isFalse,
    );
  });

  group('what it is declared for', () {
    test('the manifest asks for it, and says why', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest.contains('android.permission.SYSTEM_ALERT_WINDOW'),
        isTrue,
      );
      // A permission this visible must carry its reason next to it, or the
      // next person to read the manifest will assume the app draws over
      // other apps — which it does not.
      expect(manifest.contains('foreground service'), isTrue);
    });

    test('the native side can both check it and open the screen', () {
      final activity = File(
        'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/'
        'MainActivity.kt',
      ).readAsStringSync();

      expect(activity.contains('"canDrawOverlays" ->'), isTrue);
      expect(activity.contains('"requestOverlayPermission" ->'), isTrue);
      expect(
        activity.contains('Settings.ACTION_MANAGE_OVERLAY_PERMISSION'),
        isTrue,
      );
    });

    test('Settings offers it only while it is off', () {
      // A permanent row would be noise on every device where the adhan
      // already works, and would keep offering a screen whose switch is
      // already on.
      final screen = File(
        'lib/features/settings/presentation/settings_screen.dart',
      ).readAsStringSync();

      expect(screen.contains('if (!canAppearOnTop) ...['), isTrue);
      expect(screen.contains("'settings_screen.appear_on_top'"), isTrue);
    });
  });
}
