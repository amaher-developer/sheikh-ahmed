import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../links/app_links.dart';

/// Shares a short description of the app with the store link(s) underneath.
///
/// Android lists both stores, since the person receiving the message may be
/// on either. iOS lists only the App Store: App Review Guideline 2.3.10 asks
/// iOS apps not to mention other mobile platforms, so the Google Play line
/// stays out there.
Future<void> shareApp(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  final links = <(String, String)>[
    if (!isIos) ('share.android'.tr(), AppLinks.googlePlay),
    ('share.iphone'.tr(), AppLinks.appStore),
  ];
  final text = [
    'share.message'.tr(),
    if (links.isNotEmpty) '',
    // A single link needs no label; two are told apart by platform.
    if (links.length == 1) links.single.$2,
    if (links.length > 1)
      for (final (label, url) in links) '$label: $url',
  ].join('\n');
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'app_name'.tr(),
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    ),
  );
}

/// Shares arbitrary text (e.g. the ayah of the day) via the system sheet.
Future<void> shareText(BuildContext context, String text) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'app_name'.tr(),
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    ),
  );
}
