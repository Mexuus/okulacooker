/// Native (iOS) implementations of the export actions. The OS share sheet and
/// the system print dialog are both available here, so these are thin
/// wrappers over `share_plus` and `printing`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// iOS and Android always have a share sheet.
bool get canSystemShare => true;

Future<bool> systemShare({required String title, required String text}) async {
  final result = await Share.share(text, subject: title);
  return result.status != ShareResultStatus.dismissed;
}

/// There is no download folder to drop a file into, so hand the contents to
/// the share sheet instead — the user can save it to Files from there.
Future<void> saveTextFile({
  required String filename,
  required String mime,
  required String content,
}) async {
  await Share.shareXFiles(
    [
      XFile.fromData(
        Uint8List.fromList(utf8.encode(content)),
        mimeType: mime,
        name: filename,
      ),
    ],
    subject: filename,
  );
}

Future<void> printHtml(String html, {String title = 'OkulaCooker'}) async {
  await Printing.layoutPdf(
    name: title,
    // The replacement for convertHtml would mean bundling a web view just to
    // lay out a shopping list, and this still renders correctly on iOS.
    // ignore: deprecated_member_use
    onLayout: (format) => Printing.convertHtml(format: format, html: html),
  );
}
