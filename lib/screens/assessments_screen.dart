import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../widgets/async_list.dart';
import 'quiz_attempt_screen.dart';

/// Students: tests and assignments. Setting and marking work stays on the web app.
class AssessmentsScreen extends StatelessWidget {
  const AssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.read<AuthService>().user!.role != 'STUDENT') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Creating, publishing and marking tests and assignments is available on the web app.', textAlign: TextAlign.center),
        ),
      );
    }
    return const DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [Tab(text: 'Tests'), Tab(text: 'Assignments')]),
        Expanded(child: TabBarView(children: [_TestsTab(), _AssignmentsTab()])),
      ]),
    );
  }
}

class _TestsTab extends StatefulWidget {
  const _TestsTab();

  @override
  State<_TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<_TestsTab> {
  Key _refresh = UniqueKey();

  /// A test that needs the secure desktop app, a camera or a microphone cannot be taken here.
  bool _needsDesktop(Map<String, dynamic> t) =>
      t['secureMode'] == true || t['requireCamera'] == true || t['requireMicrophone'] == true;

  Future<void> _start(Map<String, dynamic> t) async {
    final api = context.read<AuthService>().api.dio;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final resuming = t['inProgressAttemptId'] != null;
    try {
      final res = resuming
          ? await api.get('/api/quiz-attempts/${t['inProgressAttemptId']}')
          : await api.post('/api/quizzes/${t['id']}/attempts');
      await navigator.push(MaterialPageRoute(builder: (_) => QuizAttemptScreen(paper: res.data as Map<String, dynamic>)));
      if (mounted) setState(() => _refresh = UniqueKey());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not start the test.'))));
    }
  }

  Future<void> _results(Map<String, dynamic> t) async {
    final api = context.read<AuthService>().api.dio;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(t['title'] as String? ?? 'Results')),
        body: AsyncBody<List<dynamic>>(
          load: () async => (await api.get('/api/quizzes/${t['id']}/attempts/mine')).data as List,
          isEmpty: (a) => a.isEmpty,
          emptyText: 'No attempts yet.',
          builder: (context, attempts, _) => ListView(
            children: [
              for (final a in attempts.cast<Map<String, dynamic>>())
                ListTile(
                  title: Text('Attempt ${a['attemptNo']} · ${a['status']}'),
                  subtitle: Text(a['resultVisible'] == true && a['percentage'] != null ? '${(a['percentage'] as num).toStringAsFixed(1)}% · ${a['passed'] == true ? 'Passed' : 'Not passed'}' : 'Result not released'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    final full = (await api.get('/api/quiz-attempts/${a['attemptId']}/result')).data as Map<String, dynamic>;
                    await nav.push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Result')), body: QuizResultView(result: full))));
                  },
                ),
            ],
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      key: _refresh,
      load: () async => (await api.get('/api/quizzes/available')).data as List,
      isEmpty: (t) => t.isEmpty,
      emptyText: 'No tests right now.',
      builder: (context, tests, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: tests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = tests[i] as Map<String, dynamic>;
            final desktopOnly = _needsDesktop(t);
            final resuming = t['inProgressAttemptId'] != null;
            final canStart = resuming || t['canStart'] == true;
            final used = t['attemptsUsed'] as num? ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['title'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${t['durationMinutes']} min · ${t['totalMarks']} marks · pass ${t['passPercentage']}% · attempts $used/${t['attemptsAllowed']}'),
                  if (t['availableUntil'] != null) Text('Open until ${t['availableUntil']}'),
                  if (t['bestPercentage'] != null) Text('Best ${(t['bestPercentage'] as num).toStringAsFixed(1)}%${t['passed'] == true ? ' · Passed' : ''}'),
                  const SizedBox(height: 10),
                  if (desktopOnly)
                    Text('This test must be taken in the secure desktop app.', style: TextStyle(color: Theme.of(context).colorScheme.error))
                  else
                    Text(t['openNow'] == true ? 'Open now' : 'Not open', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (used > 0 || resuming) OutlinedButton(onPressed: () => _results(t), child: const Text('Results')),
                    const Spacer(),
                    FilledButton(
                      onPressed: desktopOnly || !canStart ? null : () => _start(t),
                      child: Text(resuming ? 'Resume' : 'Start'),
                    ),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async => (await api.get('/api/assignments/mine')).data as List,
      isEmpty: (a) => a.isEmpty,
      emptyText: 'No assignments.',
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = items[i] as Map<String, dynamic>;
            final mine = a['mySubmission'] as Map<String, dynamic>?;
            return Card(
              child: ListTile(
                title: Text(a['title'] as String? ?? ''),
                subtitle: Text('Due ${a['dueAt']} · ${a['maxMarks']} marks\n${mine == null ? (a['overdue'] == true ? 'Overdue' : 'Not submitted') : mine['status']}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssignmentScreen(assignmentId: (a['id'] as num).toInt())));
                  await reload();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final _answer = TextEditingController();
  bool _busy = false;
  bool _filled = false;
  Key _refresh = UniqueKey();

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_answer.text.trim().isEmpty) return;
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await api.post('/api/assignments/${widget.assignmentId}/submissions', data: {'textAnswer': _answer.text});
      messenger.showSnackBar(const SnackBar(content: Text('Submitted.')));
      if (mounted) setState(() => _refresh = UniqueKey());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not submit.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment')),
      body: AsyncBody<Map<String, dynamic>>(
        key: _refresh,
        load: () async => (await api.get('/api/assignments/${widget.assignmentId}')).data as Map<String, dynamic>,
        builder: (context, a, _) {
          final mine = a['mySubmission'] as Map<String, dynamic>?;
          final evaluated = mine != null && (mine['status'] == 'EVALUATED');
          final closed = a['overdue'] == true && a['allowLate'] != true;
          if (!_filled && mine?['textAnswer'] != null) {
            _answer.text = mine!['textAnswer'] as String;
            _filled = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(a['title'] as String? ?? '', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Due ${a['dueAt']} · ${a['maxMarks']} marks${a['overdue'] == true ? ' · overdue' : ''}'),
              if (a['instructions'] != null) ...[const SizedBox(height: 12), Text(a['instructions'] as String)],
              if (a['attachmentRef'] != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('The attached file opens on the web app for now.')),
              if (mine != null) ...[
                const Divider(height: 32),
                Text('Your submission: ${mine['status']}', style: Theme.of(context).textTheme.titleMedium),
                if (mine['marks'] != null) Text('Marks: ${mine['marks']} / ${a['maxMarks']}'),
                if (mine['feedback'] != null) Text('Feedback: ${mine['feedback']}'),
              ],
              const SizedBox(height: 16),
              if (evaluated)
                const Text('This has been marked.')
              else if (closed)
                const Text('The deadline has passed and late work is not accepted.')
              else ...[
                TextField(
                  controller: _answer,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Your answer'),
                ),
                const SizedBox(height: 4),
                const Text('File uploads are available on the web app.', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(mine == null ? 'Submit' : 'Submit again'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
