import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';

/// Sitting a test: one question at a time, a countdown, autosave, then the result.
/// Choice, true/false, short answer and coding (typed as text) are supported; secure tests never reach this screen.
class QuizAttemptScreen extends StatefulWidget {
  const QuizAttemptScreen({super.key, required this.paper});

  /// The AttemptViewResponse from starting or resuming an attempt.
  final Map<String, dynamic> paper;

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  late final List<Map<String, dynamic>> _questions = (widget.paper['questions'] as List).cast<Map<String, dynamic>>();
  late final int _attemptId = (widget.paper['attemptId'] as num).toInt();
  final Map<int, Set<int>> _selected = {};
  final Map<int, TextEditingController> _text = {};
  final Stopwatch _clock = Stopwatch()..start();
  late final int _startSeconds = (widget.paper['secondsRemaining'] as num).toInt();
  Timer? _tick;
  Timer? _autosave;
  int _index = 0;
  bool _submitting = false;
  Map<String, dynamic>? _result;

  int get _remaining => (_startSeconds - _clock.elapsed.inSeconds).clamp(0, 1 << 30);

  @override
  void initState() {
    super.initState();
    for (final q in _questions) {
      _text[(q['id'] as num).toInt()] = TextEditingController();
    }
    for (final a in (widget.paper['savedAnswers'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final id = (a['questionId'] as num).toInt();
      _selected[id] = ((a['selectedOptionIds'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
      _text[id]?.text = a['answerText'] as String? ?? '';
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == 0 && !_submitting && _result == null) {
        _submit(auto: true);
      } else {
        setState(() {});
      }
    });
    _autosave = Timer.periodic(const Duration(seconds: 30), (_) => _save());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _autosave?.cancel();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _answers() {
    final out = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final id = (q['id'] as num).toInt();
      final type = q['type'] as String;
      final text = _text[id]!.text;
      if (type == 'SHORT_ANSWER' || type == 'CODING') {
        if (text.trim().isEmpty) continue;
        out.add({'questionId': id, 'answerText': text, if (type == 'CODING' && q['codeLanguage'] != null) 'codeLanguage': q['codeLanguage']});
      } else {
        final sel = _selected[id];
        if (sel == null || sel.isEmpty) continue;
        out.add({'questionId': id, 'selectedOptionIds': sel.toList()});
      }
    }
    return out;
  }

  /// Best effort: a failed autosave must not interrupt the test, the final submit carries every answer anyway.
  Future<void> _save() async {
    if (_submitting || _result != null) return;
    try {
      await context.read<AuthService>().api.dio.put('/api/quiz-attempts/$_attemptId/answers', data: {'answers': _answers()});
    } catch (_) {}
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    if (!auto) {
      final answered = _answers().length;
      final ok = await _confirm('Submit test?', 'You answered $answered of ${_questions.length} questions. You cannot change answers after submitting.', 'Submit');
      if (!ok) return;
    }
    setState(() => _submitting = true);
    try {
      final res = await api.post('/api/quiz-attempts/$_attemptId/submit', data: {'answers': _answers()});
      if (mounted) setState(() => _result = res.data as Map<String, dynamic>);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not submit. Try again.'))));
      }
    }
  }

  String _clockText() {
    final r = _remaining;
    final h = r ~/ 3600;
    final m = (r % 3600) ~/ 60;
    final s = r % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return Scaffold(appBar: AppBar(title: const Text('Result')), body: QuizResultView(result: _result!));

    final q = _questions[_index];
    final id = (q['id'] as num).toInt();
    final type = q['type'] as String;
    final options = (q['options'] as List? ?? const []).cast<Map<String, dynamic>>();
    final low = _remaining < 300;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirm('Leave the test?', 'The timer keeps running and you can come back to resume until it ends.', 'Leave');
        if (leave && mounted) {
          await _save();
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.paper['title'] as String? ?? 'Test'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(_clockText(), style: TextStyle(fontWeight: FontWeight.bold, color: low ? Theme.of(context).colorScheme.error : null)),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _questions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final qid = (_questions[i]['id'] as num).toInt();
                  final answered = (_selected[qid]?.isNotEmpty ?? false) || (_text[qid]?.text.trim().isNotEmpty ?? false);
                  return ChoiceChip(
                    label: Text('${i + 1}'),
                    selected: i == _index,
                    avatar: answered ? const Icon(Icons.check, size: 14) : null,
                    onSelected: (_) {
                      _save();
                      setState(() => _index = i);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Question ${_index + 1} of ${_questions.length} · ${q['marks']} marks', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(q['questionText'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (type == 'SHORT_ANSWER' || type == 'CODING') ...[
              if (type == 'CODING' && q['codeLanguage'] != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Language: ${q['codeLanguage']}')),
              TextField(
                controller: _text[id],
                minLines: type == 'CODING' ? 10 : 3,
                maxLines: type == 'CODING' ? 20 : 6,
                style: type == 'CODING' ? const TextStyle(fontFamily: 'monospace') : null,
                autocorrect: type != 'CODING',
                enableSuggestions: type != 'CODING',
                decoration: InputDecoration(border: const OutlineInputBorder(), hintText: type == 'CODING' ? 'Write your code here' : 'Your answer'),
                onChanged: (_) => setState(() {}),
              ),
            ] else if (type == 'MULTI_CHOICE') ...[
              for (final o in options)
                CheckboxListTile(
                  value: _selected[id]?.contains((o['id'] as num).toInt()) ?? false,
                  title: Text(o['optionText'] as String? ?? ''),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (on) => setState(() {
                    final set = _selected.putIfAbsent(id, () => {});
                    final oid = (o['id'] as num).toInt();
                    on == true ? set.add(oid) : set.remove(oid);
                  }),
                ),
            ] else ...[
              for (final o in options)
                RadioListTile<int>(
                  value: (o['id'] as num).toInt(),
                  groupValue: _selected[id]?.firstOrNull,
                  title: Text(o['optionText'] as String? ?? ''),
                  onChanged: (v) => setState(() => _selected[id] = {if (v != null) v}),
                ),
            ],
            const SizedBox(height: 24),
            Row(children: [
              OutlinedButton(
                onPressed: _index == 0
                    ? null
                    : () {
                        _save();
                        setState(() => _index--);
                      },
                child: const Text('Previous'),
              ),
              const Spacer(),
              if (_index < _questions.length - 1)
                FilledButton.tonal(
                  onPressed: () {
                    _save();
                    setState(() => _index++);
                  },
                  child: const Text('Next'),
                )
              else
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
                ),
            ]),
            if (_index < _questions.length - 1) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _submitting ? null : _submit, child: const Text('Submit test'))),
            ],
          ],
        ),
      ),
    );
  }
}

/// An attempt's outcome. Answers are shown only when the institute has released the result.
class QuizResultView extends StatelessWidget {
  const QuizResultView({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final visible = result['resultVisible'] == true;
    final passed = result['passed'];
    final answers = (result['answers'] as List?)?.cast<Map<String, dynamic>>();
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(result['quizTitle'] as String? ?? '', style: text.titleLarge),
        Text('Attempt ${result['attemptNo']} · ${result['status']}'),
        const SizedBox(height: 16),
        if (!visible)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Your answers are submitted. The result will be shown when your trainer releases it.')))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('${result['score'] ?? '-'} / ${result['totalMarks']}', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(result['percentage'] == null ? '' : '${(result['percentage'] as num).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                if (passed != null)
                  Chip(
                    label: Text(passed == true ? 'Passed' : 'Not passed'),
                    backgroundColor: passed == true ? Colors.green.shade100 : Theme.of(context).colorScheme.errorContainer,
                  ),
                Text('Pass mark ${result['passPercentage']}%'),
              ]),
            ),
          ),
        if (result['terminatedReason'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Ended early: ${result['terminatedReason']}')),
        if (visible && answers != null) ...[
          const SizedBox(height: 16),
          Text('Review', style: text.titleMedium),
          for (final a in answers)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(a['correct'] == true ? Icons.check_circle : Icons.cancel, color: a['correct'] == true ? Colors.green : Theme.of(context).colorScheme.error, size: 18),
                    const SizedBox(width: 6),
                    Text('${a['marksAwarded']} / ${a['marks']}'),
                  ]),
                  const SizedBox(height: 6),
                  Text(a['questionText'] as String? ?? ''),
                  ..._detail(context, a),
                  if (a['explanation'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Explanation: ${a['explanation']}')),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _detail(BuildContext context, Map<String, dynamic> a) {
    final options = (a['options'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (options.isNotEmpty) {
      final chosen = ((a['selectedOptionIds'] as List?) ?? const []).toSet();
      final right = ((a['correctOptionIds'] as List?) ?? const []).toSet();
      return [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${right.contains(o['id']) ? '✓' : chosen.contains(o['id']) ? '✗' : '•'} ${o['optionText']}${chosen.contains(o['id']) ? '  (your answer)' : ''}',
              style: TextStyle(color: right.contains(o['id']) ? Colors.green.shade700 : null, fontWeight: chosen.contains(o['id']) ? FontWeight.bold : null),
            ),
          ),
      ];
    }
    return [
      if (a['answerText'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Your answer: ${a['answerText']}')),
      if (a['testsTotal'] != null) Text('Tests passed: ${a['testsPassed']} / ${a['testsTotal']}'),
    ];
  }
}
