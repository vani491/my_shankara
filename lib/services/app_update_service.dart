import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateType { none, soft, force }

class UpdateCheckResult {
  const UpdateCheckResult(this.type, {this.latestVersion});
  final UpdateType type;
  final String? latestVersion;
}

/// Compares the installed version with Firestore doc `app_config/version`:
///   stableVersion  (string, e.g. "1.0.4")  installed < stable  -> force update
///   latestVersion  (string, e.g. "1.0.6")  installed < latest  -> soft update
/// Optional string fields: iosAppId (numeric App Store id), androidUrl, iosUrl.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _androidPackage = 'com.zeroomni.myshankara';
  // TODO: set your numeric App Store ID here, or put `iosAppId` in Firestore.
  static const _fallbackIosAppId = '';

  Map<String, dynamic> _config = const {};

  Future<UpdateCheckResult> check() async {
    try {
      final snap = await FirebaseFirestore.instance
          .doc('app_config/version')
          .get()
          .timeout(const Duration(seconds: 5));
      _config = snap.data() ?? const {};
      final current = (await PackageInfo.fromPlatform()).version;
      final stable = _config['stableVersion'] as String?;
      final latest = _config['latestVersion'] as String?;

      if (stable != null && _compare(current, stable) < 0) {
        return UpdateCheckResult(UpdateType.force, latestVersion: latest ?? stable);
      }
      if (latest != null && _compare(current, latest) < 0) {
        return UpdateCheckResult(UpdateType.soft, latestVersion: latest);
      }
    } catch (e) {
      // Never block the app because the version check failed.
      debugPrint('Update check failed (ignored): $e');
    }
    return const UpdateCheckResult(UpdateType.none);
  }

  Future<void> openStore() async {
    final String url;
    if (Platform.isIOS) {
      final id = (_config['iosAppId'] as String?) ?? _fallbackIosAppId;
      url = (_config['iosUrl'] as String?) ?? 'https://apps.apple.com/app/id$id';
    } else {
      url = (_config['androidUrl'] as String?) ??
          'https://play.google.com/store/apps/details?id=$_androidPackage';
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Numeric dotted compare; ignores any "+build" / "-pre" suffix.
  int _compare(String a, String b) {
    List<int> parse(String v) => v
        .split(RegExp(r'[+-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final x = parse(a), y = parse(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final xi = i < x.length ? x[i] : 0, yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi.compareTo(yi);
    }
    return 0;
  }
}
