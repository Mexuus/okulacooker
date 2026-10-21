/// Export plumbing that differs between the browser and a native build.
///
/// The web build prints real HTML through a hidden iframe and downloads files
/// with a Blob, because the PDF-based path the `printing` package uses on the
/// web is blocked by browsers once the user's click has been handed off to an
/// async PDF build.
library;

export 'export_io_stub.dart' if (dart.library.js_interop) 'export_io_web.dart';
