import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';

Color _bandColor(BuildContext context, String? band) {
  switch (band) {
    case 'GOOD':
      return Colors.green;
    case 'FAIR':
      return Colors.orange;
    case 'LOW':
      return Theme.of(context).colorScheme.error;
    default:
      return Theme.of(context).colorScheme.outline;
  }
}

/// The signed-in student's own report: indicators, per-course progress, attendance and what to do next.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<Map<String, dynamic>>(
      load: () async => (await api.get('/api/reports/me/progress')).data as Map<String, dynamic>,
      builder: (context, r, reload) {
        final indicators = (r['indicators'] as List?) ?? const [];
        final courses = (r['courses'] as List?) ?? const [];
        final suggestions = (r['suggestions'] as List?) ?? const [];
        final att = r['attendance'] as Map<String, dynamic>?;
        final unavailable = (r['unavailable'] as List?) ?? const [];
        final text = Theme.of(context).textTheme;

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (unavailable.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Could not load just now: ${unavailable.join(', ')}. Pull down to retry.'),
                  ),
                ),
              if (indicators.isNotEmpty) ...[
                Text('Overview', style: text.titleMedium),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    for (final i in indicators.cast<Map<String, dynamic>>())
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(i['percent'] == null ? 'No data' : '${(i['percent'] as num).round()}%',
                                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _bandColor(context, i['band'] as String?))),
                            Text(i['label'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ),
                  ],
                ),
              ],
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('What to do next', style: text.titleMedium),
                for (final s in suggestions.cast<Map<String, dynamic>>())
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb_outline),
                      title: Text(s['title'] as String? ?? ''),
                      subtitle: Text(s['detail'] as String? ?? ''),
                    ),
                  ),
              ],
              if (courses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Courses', style: text.titleMedium),
                for (final c in courses.cast<Map<String, dynamic>>())
                  Card(
                    child: ExpansionTile(
                      title: Text(c['courseTitle'] as String? ?? 'Course #${c['courseId']}'),
                      subtitle: Text('${c['completedLessons']} of ${c['totalLessons']} lessons · ${((c['progressPercent'] as num?) ?? 0).round()}%'),
                      children: [
                        for (final m in (c['modules'] as List? ?? const []).cast<Map<String, dynamic>>())
                          ListTile(
                            dense: true,
                            title: Text(m['title'] as String? ?? ''),
                            trailing: Text('${m['completed']}/${m['lessons']}'),
                          ),
                      ],
                    ),
                  ),
              ],
              if (att != null) ...[
                const SizedBox(height: 16),
                Text('Attendance', style: text.titleMedium),
                Card(
                  child: ListTile(
                    title: Text(att['percent'] == null ? 'No classes counted yet' : '${(att['percent'] as num).round()}% attendance'),
                    subtitle: Text('Attended ${att['attended']} of ${att['counted']} · absent ${att['absent']} · excused ${att['excused']}'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
