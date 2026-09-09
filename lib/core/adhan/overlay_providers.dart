import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app may "appear on top" — Android's *display over other apps*.
///
/// The app draws nothing over other apps. What it needs is the side effect:
/// from Android 12 an app may not start a foreground service while it is in
/// the background, and holding this permission is one of the documented
/// exemptions. The adhan is exactly that case — an alarm fires with the app
/// closed and has to start the playback service to sound the call. Without an
/// exemption Android refuses the start and the prayer arrives as a plain
/// notification instead of the adhan (see AdhanAlarmReceiver.kt, which
/// catches the refusal and posts one).
///
/// The alarm-clock alarms the app already registers carry their own
/// exemption, and on most devices that is enough. This is the second lock on
/// the same door, and it is the one manufacturers with aggressive battery
/// managers tend to leave standing — which is why it is worth offering.
class OverlayPermissionNotifier extends StateNotifier<bool> {
  static const _channel = MethodChannel('com.manassa.sheikhahmed/widget');

  late final AppLifecycleListener _lifecycle;

  OverlayPermissionNotifier() : super(true) {
    refresh();
    // Granted in a system screen, outside this app entirely, and revocable
    // there at any time. Coming back to the foreground is the only reliable
    // moment to notice either.
    _lifecycle = AppLifecycleListener(onResume: refresh);
  }

  /// Only Android has the notion at all.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Defaults to allowed on every failure path, deliberately — the same rule
  /// [ExactAlarmsNotifier] follows. Being unable to *ask* is not evidence the
  /// permission is missing, and guessing the other way would show a prompt to
  /// people who have nothing to fix.
  Future<void> refresh() async {
    if (!isSupported) return;
    bool allowed;
    try {
      allowed = await _channel.invokeMethod<bool>('canDrawOverlays') ?? true;
    } catch (_) {
      allowed = true;
    }
    if (!mounted || allowed == state) return;
    state = allowed;
  }

  /// Opens the system's "Display over other apps" screen for this app.
  ///
  /// Returns false when there was nothing to open — already granted, or a
  /// device that ships no such screen. Deliberately does not wait for an
  /// outcome: the call returns as soon as the screen is launched, long
  /// before the user has decided, and [refresh] on the next resume is what
  /// actually observes it.
  Future<bool> request() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }
}

final overlayPermissionProvider =
    StateNotifierProvider<OverlayPermissionNotifier, bool>(
      (ref) => OverlayPermissionNotifier(),
    );
