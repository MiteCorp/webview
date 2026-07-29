import 'package:flutter/material.dart';

/// Compile-time configuration for the reusable WebView application.
///
/// Override string and boolean values with `--dart-define` or
/// `--dart-define-from-file` without changing the Dart source.
abstract final class AppConfig {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'TukuGaming',
  );

  static const String websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://www.tukugaming.com/id',
  );

  static const bool enablePerformanceMode = bool.fromEnvironment(
    'ENABLE_PERFORMANCE_MODE',
    defaultValue: true,
  );

  static const Color primaryColor = Color(0xFFF3B332);
  static const Color backgroundColor = Color(0xFF121212);

  static final Uri websiteUri = _parseWebsiteUri();

  static bool isFirstPartyUri(Uri uri) {
    final String configuredHost = _normalizeHost(websiteUri.host);
    final String candidateHost = _normalizeHost(uri.host);

    if (configuredHost.isEmpty || candidateHost.isEmpty) {
      return false;
    }

    return candidateHost == configuredHost ||
        candidateHost.endsWith('.$configuredHost');
  }

  static Uri _parseWebsiteUri() {
    final Uri uri = Uri.parse(websiteUrl);
    final bool usesWebScheme = uri.scheme == 'https' || uri.scheme == 'http';

    if (!usesWebScheme || uri.host.isEmpty) {
      throw FormatException(
        'WEBSITE_URL harus berupa URL http/https yang valid: $websiteUrl',
      );
    }

    return uri;
  }

  static String _normalizeHost(String host) {
    final String normalized = host.toLowerCase();
    return normalized.startsWith('www.')
        ? normalized.substring('www.'.length)
        : normalized;
  }
}
