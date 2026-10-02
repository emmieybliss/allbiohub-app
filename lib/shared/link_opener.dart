import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/routing/app_router.dart';
import '../core/routing/routes.dart';

/// Opens a link the right way:
/// - allbiohub.com stories, categories and startups open in the app;
/// - other allbiohub.com pages (forms, account pages) open in an in-app
///   browser tab, which also avoids bouncing back into the app via App Links;
/// - everything else opens in the person's browser or the matching app.
///
/// Pass `inApp: false` to always use the browser (e.g. "Visit website").
Future<void> openLink(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  bool inApp = true,
}) async {
  final parser = ref.read(deepLinkParserProvider);
  final location = inApp ? parser.locationFor(uri) : null;
  if (location != null) {
    // Tab roots switch tabs; everything else opens on top.
    const tabs = {
      Routes.home,
      Routes.discover,
      Routes.startups,
      Routes.saved,
      Routes.profile,
    };
    tabs.contains(location) ? context.go(location) : context.push(location);
    return;
  }
  if (uri.scheme != 'https' &&
      uri.scheme != 'http' &&
      uri.scheme != 'mailto' &&
      uri.scheme != 'tel') {
    return; // Ignore javascript:, data: and other unsafe schemes.
  }
  final launched = await launchUrl(
    uri,
    mode: parser.isSiteUrl(uri)
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Couldn't open that link.")));
  }
}
