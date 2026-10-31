import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URI in another app (dialer, maps). Tests replace it.
abstract class UrlOpener {
  /// True when an app handled the URI.
  Future<bool> open(Uri uri);
}

class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

final urlOpenerProvider =
    Provider<UrlOpener>((ref) => const UrlLauncherOpener());
