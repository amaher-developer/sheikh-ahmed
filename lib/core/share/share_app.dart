import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a short description of the app. No store link is included yet —
/// the app isn't published, and a fabricated Play Store/App Store URL
/// would just be a broken link.
Future<void> shareApp(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: 'share.message'.tr(),
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
