import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/recipe.dart';
import '../services/format.dart';

/// One step in cook mode: an action with the phase it belongs to.
class CookStep {
  final String phase;
  final int phaseNumber;
  final RecipeAction action;
  const CookStep(this.phase, this.phaseNumber, this.action);
}

List<CookStep> cookSteps(Recipe r) => [
      for (final (i, p) in r.phases.indexed)
        for (final a in p.actions) CookStep(p.name, i + 1, a),
    ];

final _durationText = RegExp(
    r'(\d+(?:\.\d+)?)(?:\s*(?:–|-|to)\s*(\d+(?:\.\d+)?))?\s*(minutes?|mins?|min\b|hours?|hrs?|hr\b)',
    caseSensitive: false);

/// Timer length for a step: its explicit duration ("8 min", "2-3 hr"), else
/// the first time mentioned in the text ("simmer for 10–12 minutes"). Ranges
/// use the lower bound, so the cook checks early. Null when there's no wait
/// or it's over 12 hours.
Duration? stepTimer(RecipeAction a, String renderedBody) {
  final m = _durationText.firstMatch(a.duration ?? renderedBody);
  if (m == null) return null;
  final n = double.parse(m.group(1)!);
  final hours = m.group(3)!.toLowerCase().startsWith('h');
  final d = Duration(seconds: (n * (hours ? 3600 : 60)).round());
  if (d.inSeconds < 30 || d > const Duration(hours: 12)) return null;
  return d;
}

String _clock(Duration d) {
  final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Full-screen, step-by-step cooking view with timers. Keeps the screen on.
class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int servings;
  const CookModeScreen({super.key, required this.recipe, required this.servings});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late final List<CookStep> _steps = cookSteps(widget.recipe);
  final _pages = PageController();
  int _index = 0;

  double get _scale => widget.servings / widget.recipe.baseServings;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _index == _steps.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_index + 1) / _steps.length),
        ),
      ),
      body: _steps.isEmpty
          ? const Center(child: Text('This recipe has no steps.'))
          : PageView.builder(
              controller: _pages,
              itemCount: _steps.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final s = _steps[i];
                final body = renderActionBody(s.action, _scale);
                final timer = stepTimer(s.action, body);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    Text('Step ${i + 1} of ${_steps.length} · ${s.phase}',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '${s.action.verb} ',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: body),
                      ]),
                      style: theme.textTheme.headlineSmall?.copyWith(height: 1.35),
                    ),
                    if (timer != null) ...[
                      const SizedBox(height: 28),
                      StepTimer(key: ValueKey('timer-$i'), duration: timer),
                    ],
                  ],
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _index == 0 ? null : () => _go(_index - 1),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: last ? () => Navigator.of(context).pop() : () => _go(_index + 1),
                  icon: Icon(last ? Icons.check : Icons.arrow_forward),
                  label: Text(last ? 'Done' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A countdown for one step: start, pause, reset, and an alert when done.
class StepTimer extends StatefulWidget {
  final Duration duration;
  const StepTimer({super.key, required this.duration});

  @override
  State<StepTimer> createState() => _StepTimerState();
}

class _StepTimerState extends State<StepTimer> {
  late Duration _left = widget.duration;
  Timer? _ticker;
  DateTime? _endsAt;

  bool get _running => _ticker != null;
  bool get _done => _left == Duration.zero;

  void _start() {
    _endsAt = DateTime.now().add(_left);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final left = _endsAt!.difference(DateTime.now());
      if (left <= Duration.zero) {
        _stop();
        setState(() => _left = Duration.zero);
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      } else {
        setState(() => _left = Duration(seconds: left.inSeconds + 1));
      }
    });
    setState(() {});
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: _done ? scheme.tertiaryContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(_done ? Icons.alarm_on : Icons.timer_outlined,
                size: 32, color: _done ? scheme.onTertiaryContainer : scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _done ? 'Time’s up!' : _clock(_left),
                  style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
            if (!_done)
              IconButton.filled(
                tooltip: _running ? 'Pause timer' : 'Start timer',
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                onPressed: () => _running ? setState(_stop) : _start(),
              ),
            IconButton(
              tooltip: 'Reset timer',
              icon: const Icon(Icons.replay),
              onPressed: () => setState(() {
                _stop();
                _left = widget.duration;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
