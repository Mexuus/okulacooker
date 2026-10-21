import 'package:flutter/material.dart';

import '../services/export_formats.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';

Future<void> showExportSheet(
  BuildContext context,
  AppState state,
  ExportDoc doc,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExportSheet(state: state, doc: doc),
  );
}

class _ExportSheet extends StatefulWidget {
  final AppState state;
  final ExportDoc doc;
  const _ExportSheet({required this.state, required this.doc});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportOptions _options = ExportOptions(
    groupByAisle: widget.state.settings.exportGroupByAisle,
    includePrices: widget.state.settings.exportIncludePrices,
    includeOwned: widget.state.settings.exportIncludeOwned,
  );
  bool _busy = false;

  void _setOptions(ExportOptions next) {
    setState(() => _options = next);
    widget.state.updateSettings(widget.state.settings.copyWith(
      exportGroupByAisle: next.groupByAisle,
      exportIncludePrices: next.includePrices,
      exportIncludeOwned: next.includeOwned,
    ));
  }

  Future<void> _run(Future<ExportResult> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    ExportResult result;
    try {
      result = await action();
    } catch (e) {
      result = ExportResult(ExportOutcome.failed, 'Export failed: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.outcome == ExportOutcome.cancelled) return;

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(result.message),
      backgroundColor: result.ok ? null : scheme.errorContainer,
      duration: Duration(seconds: result.ok ? 3 : 6),
    ));
    if (result.ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = widget.doc;
    final settings = widget.state.settings;
    final hasWebhook = settings.exportWebhookUrl.trim().isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Export ${doc.title.toLowerCase()}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Everything here works offline and needs no account.',
              style: theme.textTheme.bodySmall,
            ),
            if (doc.showOptions) ...[
              const SizedBox(height: 8),
              _OptionSwitch(
                label: 'Group by aisle',
                hint: 'Turn off for a plain list — better for Reminders and Alexa',
                value: _options.groupByAisle,
                onChanged: (v) => _setOptions(_options.copyWith(groupByAisle: v)),
              ),
              _OptionSwitch(
                label: 'Include prices',
                value: _options.includePrices,
                onChanged: (v) => _setOptions(_options.copyWith(includePrices: v)),
              ),
              _OptionSwitch(
                label: 'Include pantry items you already have',
                value: _options.includeOwned,
                onChanged: (v) => _setOptions(_options.copyWith(includeOwned: v)),
              ),
            ],
            const SizedBox(height: 8),
            if (_busy) const LinearProgressIndicator(),
            _Action(
              icon: Icons.print_outlined,
              label: 'Print',
              subtitle: 'Opens your printer dialog with a tick-box list',
              enabled: !_busy,
              onTap: () => _run(() => ExportService.printDocument(
                    doc.html(_options),
                    title: 'OkulaCooker ${doc.title}',
                  )),
            ),
            _Action(
              icon: Icons.copy_all_outlined,
              label: 'Copy as text',
              subtitle: 'Paste into any list app, or the Alexa app',
              enabled: !_busy,
              onTap: () => _run(() => ExportService.copy(doc.text(_options))),
            ),
            _Action(
              icon: Icons.ios_share,
              label: 'Share…',
              subtitle: canSystemShare
                  ? 'Reminders, Notes, Messages, AnyList…'
                  : 'This browser has no share sheet — use Copy',
              enabled: !_busy && canSystemShare,
              onTap: () => _run(() => ExportService.share(
                    title: 'OkulaCooker ${doc.title}',
                    text: doc.text(_options),
                  )),
            ),
            _Action(
              icon: Icons.checklist_rtl,
              label: 'Add to Apple Reminders',
              subtitle: 'Runs your “${settings.appleShortcutName}” shortcut',
              enabled: !_busy,
              onTap: () => _run(() => ExportService.appleShortcut(
                    shortcutName: settings.appleShortcutName,
                    text: doc.text(_options),
                  )),
            ),
            if (doc.csv != null)
              _Action(
                icon: Icons.table_chart_outlined,
                label: 'Download CSV',
                subtitle: 'For spreadsheets and local list apps',
                enabled: !_busy,
                onTap: () => _run(() => ExportService.downloadCsv(
                      filename: '${doc.fileStem}.csv',
                      csv: doc.csv!(_options),
                    )),
              ),
            _Action(
              icon: Icons.mail_outline,
              label: 'Email it',
              subtitle: 'Opens your mail app with the list in the body',
              enabled: !_busy,
              onTap: () => _run(() => ExportService.email(
                    subject: 'OkulaCooker ${doc.title}',
                    body: doc.text(_options),
                  )),
            ),
            if (doc.json != null)
              _Action(
                icon: Icons.webhook_outlined,
                label: 'Send to webhook',
                subtitle: hasWebhook
                    ? settings.exportWebhookUrl
                    : 'Add a URL in Settings → Exports to reach Alexa via '
                        'Home Assistant or n8n',
                enabled: !_busy && hasWebhook,
                onTap: () => _run(() => ExportService.webhook(
                      url: settings.exportWebhookUrl,
                      payload: doc.json!(_options),
                    )),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: hint == null ? null : Text(hint!),
        value: value,
        onChanged: onChanged,
      );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: enabled ? theme.colorScheme.primary : null),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: enabled ? onTap : null,
    );
  }
}
