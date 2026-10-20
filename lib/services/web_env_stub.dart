/// Native (iOS) builds: there is no page origin, and location permission is
/// handled by the OS, so the page is always treated as secure.
bool get isSecureContext => true;

/// The page's origin, e.g. `https://example.com`; null off the web.
String? get pageOrigin => null;

/// Navigates the current tab to [url]. No-op off the web.
void openInPage(String url) {}
