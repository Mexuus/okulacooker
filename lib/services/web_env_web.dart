import 'package:web/web.dart' as web;

/// Browsers only expose geolocation (and other powerful APIs) to secure
/// contexts: https pages and localhost.
bool get isSecureContext => web.window.isSecureContext;

String? get pageOrigin => web.window.location.origin;

void openInPage(String url) => web.window.location.assign(url);
