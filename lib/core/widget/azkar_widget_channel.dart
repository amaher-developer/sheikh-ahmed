import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the home-screen azkar widget (see AzkarWidgetProvider.kt).
///
/// The widget itself needs no Flutter involvement to run — it renders and
/// rotates natively. This exists only so the app can offer to *place* it:
/// otherwise the only route is long-pressing the wallpaper, opening the
/// widget drawer and finding the app in a long alphabetical list, which is
/// enough friction that people reasonably conclude the widget is broken.
class AzkarWidgetChannel {
  const AzkarWidgetChannel._();

  // Namespaced under the applicationId, matching MainActivity.kt.
  static const _channel = MethodChannel('com.manassa.sheikhahmed/widget');

  /// Whether the widget exists on this platform at all. It is an Android
  /// app widget with no iOS counterpart, so off Android every call here is a
  /// no-op and the app offers no way to add it.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Whether a one-tap pin is possible at all: Android 8+, and a launcher
  /// that supports pinning (a good many third-party ones don't). False on
  /// every non-Android platform.
  static Future<bool> canPin() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canPinWidget') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Redraws any placed widgets right now, so a snapshot just written by
  /// [WidgetDataService] is visible immediately rather than at the widget's
  /// next 30-minute refresh.
  static Future<void> refresh() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('refreshWidget');
    } on PlatformException {
      // Nothing to do: the widget still refreshes on its own schedule.
    } on MissingPluginException {
      // No host activity (widget tests, or the engine running headless).
    }
  }

  /// Asks the launcher to pin the widget. The launcher shows its own
  /// confirmation dialog and the user chooses where it lands, so `true`
  /// means the request was accepted, not that a widget is now on screen —
  /// Android reports no outcome without a separate broadcast.
  static Future<bool> pin() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('pinWidget') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
