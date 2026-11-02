import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../widgets/async_list.dart';

const _statuses = ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'];

/// Marks one class session: the batch roster, each student defaulting to what is already recorded, else PRESENT.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Map<int, String> _marks = {};
  final _reason = TextEditingController();
  bool _saving = false;

  int get _sessionId => (widget.session['id'] as num).toInt();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<(List<dynamic>, List<dynamic>)> _load() async {
    final api = context.read<AuthService>().api.dio;
    final roster = (await api.get('/api/batches/${widget.session['batchId']}/students')).data as List;
    final marked = (await api.get('/api/sessions/$_sessionId/attendance')).data as List;
    _marks.clear();
    for (final a in marked.cast<Map<String, dynamic>>()) {
      _marks[(a['studentId'] as num).toInt()] = a['status'] as String;
    }
    return (roster, marked);
  }

  Future<void> _save(List<dynamic> roster, bool alreadyMarked) async {
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (alreadyMarked && _reason.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Attendance was already marked. Enter a reason for the correction.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final entries = [
        for (final s in roster.cast<Map<String, dynamic>>())
          {'studentId': s['studentId'], 'status': _marks[(s['studentId'] as num).toInt()] ?? 'PRESENT'},
      ];
      await api.post('/api/sessions/$_sessionId/attendance', data: {
        'entries': entries,
        if (alreadyMarked) 'correctionReason': _reason.text.trim(),
      });
      messenger.showSnackBar(const SnackBar(content: Text('Attendance saved.')));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not save attendance.'))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Scaffold(
      appBar: AppBar(title: Text('Attendance · ${s['sessionDate']}')),
      body: AsyncBody<(List<dynamic>, List<dynamic>)>(
        load: _load,
        isEmpty: (d) => d.$1.isEmpty,
        emptyText: 'No students in this batch.',
        builder: (context, data, _) {
          final (roster, marked) = data;
          final already = marked.isNotEmpty;
          return Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (s['topic'] != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s['topic'] as String)),
                  if (already) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Already marked. Changing it needs a reason.')),
                  for (final st in roster.cast<Map<String, dynamic>>())
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(st['studentName'] as String? ?? '', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: [for (final x in _statuses) ButtonSegment(value: x, label: Text(x.substring(0, 1) + x.substring(1).toLowerCase(), style: const TextStyle(fontSize: 11)))],
                            selected: {_marks[(st['studentId'] as num).toInt()] ?? 'PRESENT'},
                            onSelectionChanged: (v) => setState(() => _marks[(st['studentId'] as num).toInt()] = v.first),
                          ),
                        ]),
                      ),
                    ),
                  if (already)
                    TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason for correction', border: OutlineInputBorder())),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(roster, already),
                    child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save attendance'),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
