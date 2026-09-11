import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the app links out to.
class AppLinks {
  const AppLinks._();

  /// The privacy policy the Google Play listing already links to. Apple also
  /// expects it to be reachable from inside the app, not only from the store
  /// page (App Review Guideline 5.1.1).
  static final privacyPolicy = Uri.parse(
    'https://claude.ai/code/artifact/4b210bce-5156-442e-a2ad-16548d043579',
  );

  /// The developer contact address shown on the store listings.
  static const supportEmailAddress = 'sheikhahmed.app@gmail.com';

  static final supportEmail = Uri(scheme: 'mailto', path: supportEmailAddress);

  /// The live Google Play listing.
  static const googlePlay =
      'https://play.google.com/store/apps/details?id=com.manassa.sheikhahmed';

  /// The App Store listing — `https://apps.apple.com/app/id<Apple ID>`.
  ///
  /// Null until the app exists in App Store Connect, which assigns the
  /// numeric Apple ID; the share message simply leaves the iPhone line out
  /// while it is null rather than sending people to a dead link.
  static const String? appStore = null;
}

/// Opens [uri] in the browser or mail app, and says so when nothing could —
/// a `mailto:` link on a phone with no mail account set up, for one.
Future<void> openExternalLink(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Treated the same as there being nothing to open it with.
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('settings_screen.link_failed'.tr())),
  );
}
