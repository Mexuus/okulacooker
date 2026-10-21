/// Browser implementations of the export actions.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const _printFrameId = 'okulacooker-print-frame';

/// Whether the browser can hand text to the OS share sheet. True on iOS
/// Safari and Android Chrome, false on most desktop browsers.
bool get canSystemShare =>
    (web.window.navigator as JSObject).has('share') &&
    (web.window.navigator as JSObject).has('canShare');

/// Opens the OS share sheet (Reminders, Notes, Messages, AnyList …).
/// Returns false when the user dismisses it or the browser refuses.
Future<bool> systemShare({required String title, required String text}) async {
  try {
    await web.window.navigator.share(web.ShareData(title: title, text: text)).toDart;
    return true;
  } catch (_) {
    // AbortError when the sheet is dismissed; NotAllowedError when the
    // gesture has expired. Neither is worth surfacing as a crash.
    return false;
  }
}

/// Downloads [content] as a file.
Future<void> saveTextFile({
  required String filename,
  required String mime,
  required String content,
}) async {
  // The BOM keeps Excel from mangling accented ingredient names in CSV.
  final body = mime.startsWith('text/csv') ? '\uFEFF$content' : content;
  final blob = web.Blob(
    [body.toJS].toJS,
    web.BlobPropertyBag(type: '$mime;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  // Give the download a moment to start before the blob is reclaimed.
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

/// Prints [html] through an offscreen iframe. Building the document is
/// synchronous, so the browser still treats this as part of the user's click.
Future<void> printHtml(String html, {String title = 'OkulaCooker'}) async {
  web.document.getElementById(_printFrameId)?.remove();

  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..id = _printFrameId
    ..setAttribute('aria-hidden', 'true')
    // Firefox refuses to print a frame that has no layout at all, so keep it
    // on the page but out of sight rather than using display:none.
    ..setAttribute(
      'style',
      'position:fixed;left:-10000px;top:0;width:820px;height:1160px;border:0;',
    );

  final ready = Completer<void>();
  frame.addEventListener(
    'load',
    ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS,
  );

  web.document.body!.append(frame);
  frame.srcdoc = html.toJS;

  await ready.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  // Safari needs a beat after load before the frame will accept print().
  await Future<void>.delayed(const Duration(milliseconds: 150));

  var printed = false;
  try {
    final win = frame.contentWindow;
    if (win != null) {
      win.focus();
      win.print();
      printed = true;
    }
  } catch (_) {
    printed = false;
  }

  if (!printed) {
    // Last resort: hand the document to a new tab and let it print itself.
    _printInNewWindow(html);
  }

  // Leave the frame in place while the print dialog is open, then tidy up.
  Timer(const Duration(minutes: 2), () => frame.remove());
}

void _printInNewWindow(String html) {
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  Timer(const Duration(minutes: 2), () => web.URL.revokeObjectURL(url));
}
