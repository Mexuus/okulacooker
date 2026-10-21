/// The destinations an export can go to: the clipboard, the system share
/// sheet, a downloaded file, the printer, an email, an Apple Shortcut or a
/// webhook the user runs themselves.
///
/// Every destination here works without an account or a subscription, and
/// none of them call a third-party service.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'export_io.dart' as io;

/// How an export attempt ended, so the UI can show the right message.
enum ExportOutcome { done, cancelled, unsupported, failed }

class ExportResult {
  final ExportOutcome outcome;
  final String message;
  const ExportResult(this.outcome, this.message);

  bool get ok => outcome == ExportOutcome.done;

  static const cancelled = ExportResult(ExportOutcome.cancelled, '');
}

/// Mail clients and some browsers truncate very long `mailto:` links, so the
/// body is trimmed with a pointer to the other export options.
const _mailtoBodyLimit = 1800;

/// True when the device can show the OS share sheet (iPhone, iPad, Android).
bool get canSystemShare => io.canSystemShare;

class ExportService {
  const ExportService._();

  static Future<ExportResult> copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return const ExportResult(ExportOutcome.done, 'Copied to the clipboard');
    } catch (e) {
      return ExportResult(ExportOutcome.failed, 'Could not copy: $e');
    }
  }

  static Future<ExportResult> share({
    required String title,
    required String text,
  }) async {
    if (!io.canSystemShare) {
      return const ExportResult(
        ExportOutcome.unsupported,
        'This browser has no share sheet — copy the list instead',
      );
    }
    try {
      final shared = await io.systemShare(title: title, text: text);
      return shared
          ? const ExportResult(ExportOutcome.done, 'Shared')
          : ExportResult.cancelled;
    } catch (e) {
      return ExportResult(ExportOutcome.failed, 'Share failed: $e');
    }
  }

  static Future<ExportResult> downloadCsv({
    required String filename,
    required String csv,
  }) async {
    try {
      await io.saveTextFile(
        filename: filename,
        mime: 'text/csv',
        content: csv,
      );
      return ExportResult(ExportOutcome.done, 'Saved $filename');
    } catch (e) {
      return ExportResult(ExportOutcome.failed, 'Could not save the file: $e');
    }
  }

  static Future<ExportResult> printDocument(
    String html, {
    required String title,
  }) async {
    try {
      await io.printHtml(html, title: title);
      return const ExportResult(ExportOutcome.done, 'Sent to the printer');
    } catch (e) {
      return ExportResult(ExportOutcome.failed, 'Could not print: $e');
    }
  }

  static Future<ExportResult> email({
    required String subject,
    required String body,
  }) async {
    final trimmed = body.length > _mailtoBodyLimit
        ? '${body.substring(0, _mailtoBodyLimit)}\n\n…trimmed to fit an email. '
            'Use Copy or the CSV export for the full list.'
        : body;
    final uri = Uri(
      scheme: 'mailto',
      query: _query({'subject': subject, 'body': trimmed}),
    );
    return _launch(
      uri,
      done: 'Opening your email app',
      failed: 'No email app is set up on this device',
    );
  }

  /// Hands the list to an Apple Shortcut, which is how an iPhone can drop it
  /// straight into Reminders. The user creates the shortcut once; its name
  /// has to match [shortcutName].
  static Future<ExportResult> appleShortcut({
    required String shortcutName,
    required String text,
  }) async {
    if (shortcutName.trim().isEmpty) {
      return const ExportResult(
        ExportOutcome.failed,
        'Set the shortcut name in Settings first',
      );
    }
    final uri = Uri.parse(
      'shortcuts://x-callback-url/run-shortcut'
      '?${_query({'name': shortcutName.trim(), 'input': 'text', 'text': text})}',
    );
    return _launch(
      uri,
      done: 'Opening Shortcuts',
      failed: 'Shortcuts is only available on an iPhone, iPad or Mac',
    );
  }

  /// POSTs the list as JSON to the user's own automation (n8n, Home
  /// Assistant, Node-RED …) — the practical way onto an Alexa shopping list,
  /// since Amazon has no public API a web app can call.
  static Future<ExportResult> webhook({
    required String url,
    required Map<String, dynamic> payload,
  }) async {
    final target = Uri.tryParse(url.trim());
    if (target == null || !target.isScheme('http') && !target.isScheme('https')) {
      return const ExportResult(
        ExportOutcome.failed,
        'That webhook address is not a valid http(s) URL',
      );
    }
    try {
      final res = await http
          .post(
            target,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ExportResult(
          ExportOutcome.done,
          'Sent to your webhook (${res.statusCode})',
        );
      }
      return ExportResult(
        ExportOutcome.failed,
        'The webhook answered ${res.statusCode}',
      );
    } catch (e) {
      return ExportResult(
        ExportOutcome.failed,
        'Could not reach the webhook. Check the URL is reachable from this '
        'device and allows cross-origin requests.',
      );
    }
  }

  static Future<ExportResult> _launch(
    Uri uri, {
    required String done,
    required String failed,
  }) async {
    try {
      final ok = await launchUrl(uri, webOnlyWindowName: '_self');
      return ok
          ? ExportResult(ExportOutcome.done, done)
          : ExportResult(ExportOutcome.unsupported, failed);
    } catch (_) {
      return ExportResult(ExportOutcome.unsupported, failed);
    }
  }
}

/// `Uri(queryParameters:)` encodes spaces as `+`, which Shortcuts and some
/// mail clients paste literally, so build the query with %20 instead.
String _query(Map<String, String> params) => params.entries
    .map((e) => '${Uri.encodeQueryComponent(e.key)}='
        '${Uri.encodeComponent(e.value)}')
    .join('&');
