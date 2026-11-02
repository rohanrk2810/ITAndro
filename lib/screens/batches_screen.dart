import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';
import 'attendance_screen.dart';

/// Batches the signed-in staff member or trainer may see; the server narrows the list to what they own.
class BatchesScreen extends StatelessWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async => (await api.get('/api/batches', queryParameters: {'page': 0, 'size': 50})).data['content'] as List,
      isEmpty: (items) => items.isEmpty,
      emptyText: 'No batches.',
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final b = items[i] as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text('${b['name']} (${b['batchCode']})'),
                subtitle: Text('${b['courseTitle']}\n${b['startTime']}-${b['endTime']} · ${b['classDays']} · ${b['enrolledCount']}/${b['capacity']} students'),
                isThreeLine: true,
                trailing: Text(b['status'] as String? ?? ''),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BatchDetailScreen(batchId: (b['id'] as num).toInt(), title: b['name'] as String? ?? '')),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BatchDetailScreen extends StatelessWidget {
  const BatchDetailScreen({super.key, required this.batchId, required this.title});

  final int batchId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: Text(title), bottom: const TabBar(tabs: [Tab(text: 'Sessions'), Tab(text: 'Students'), Tab(text: 'Attendance')])),
        body: TabBarView(children: [
          AsyncBody<List<dynamic>>(
            load: () async => (await api.get('/api/batches/$batchId/sessions')).data as List,
            isEmpty: (s) => s.isEmpty,
            emptyText: 'No sessions scheduled.',
            builder: (context, sessions, reload) => RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                children: [
                  for (final s in sessions.cast<Map<String, dynamic>>())
                    ListTile(
                      leading: Icon(s['live'] == true ? Icons.videocam : Icons.event),
                      title: Text('${s['sessionDate']} · ${s['startTime']}-${s['endTime']}'),
                      subtitle: Text(s['topic'] as String? ?? s['mode'] as String? ?? ''),
                      trailing: Text(s['status'] as String? ?? ''),
                      onTap: s['status'] == 'CANCELLED'
                          ? null
                          : () async {
                              final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AttendanceScreen(session: s)));
                              if (saved == true) await reload();
                            },
                    ),
                ],
              ),
            ),
          ),
          AsyncBody<List<dynamic>>(
            load: () async => (await api.get('/api/batches/$batchId/students')).data as List,
            isEmpty: (s) => s.isEmpty,
            emptyText: 'No students enrolled.',
            builder: (context, students, reload) => RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                children: [
                  for (final s in students.cast<Map<String, dynamic>>())
                    ListTile(
                      title: Text(s['studentName'] as String? ?? ''),
                      subtitle: Text(s['studentCode'] as String? ?? ''),
                      trailing: Text(s['status'] as String? ?? ''),
                    ),
                ],
              ),
            ),
          ),
          AsyncBody<List<dynamic>>(
            load: () async => (await api.get('/api/attendance/batches/$batchId')).data as List,
            isEmpty: (a) => a.isEmpty,
            emptyText: 'No attendance recorded yet.',
            builder: (context, rows, reload) => RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                children: [
                  for (final r in rows.cast<Map<String, dynamic>>())
                    ListTile(
                      title: Text(r['studentName'] as String? ?? ''),
                      subtitle: Text('${r['attendedSessions']} of ${r['totalSessions']} sessions'),
                      trailing: Text(
                        r['attendancePercent'] == null ? '-' : '${(r['attendancePercent'] as num).round()}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: r['belowThreshold'] == true ? Theme.of(context).colorScheme.error : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
