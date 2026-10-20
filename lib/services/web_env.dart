/// Browser facts the app needs on the web build. Native builds use the stub.
library;

export 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart';
