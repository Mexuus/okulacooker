import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Settings supplied by whoever hosts the web app, read from `config.json`
/// next to `index.html`. The Docker image writes that file from environment
/// variables at start-up; any other host can simply omit it.
class AppConfig {
  /// Secure (https) address of this same app. When someone opens it over
  /// plain http, location is blocked, so the app offers to switch here.
  final String? secureUrl;

  const AppConfig({this.secureUrl});

  static AppConfig current = const AppConfig();

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final url = (j['secureUrl'] as String?)?.trim();
    final ok = url != null && url.startsWith('https://') && Uri.tryParse(url) != null;
    return AppConfig(secureUrl: ok ? url : null);
  }

  /// Loads `config.json` relative to the page. Never throws: a missing,
  /// slow or malformed file just means "no extra settings".
  static Future<void> load({http.Client? client}) async {
    if (!kIsWeb) return;
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(Uri.base.resolve('config.json'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) current = AppConfig.fromJson(body);
    } catch (_) {
      // Non-JSON (e.g. the SPA fallback page) or network error: ignore.
    } finally {
      if (client == null) c.close();
    }
  }
}
