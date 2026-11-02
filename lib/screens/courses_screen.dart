import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async {
        final res = await api.get('/api/courses', queryParameters: {'page': 0, 'size': 50});
        return res.data['content'] as List;
      },
      isEmpty: (items) => items.isEmpty,
      emptyText: 'No courses.',
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = items[i] as Map<String, dynamic>;
            final hours = c['durationHours'];
            return Card(
              child: ListTile(
                title: Text(c['title'] as String? ?? ''),
                subtitle: Text([c['code'], c['level'], if (hours != null) '$hours h'].where((e) => e != null).join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(courseId: (c['id'] as num).toInt(), title: c['title'] as String? ?? ''),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseId, required this.title});

  final int courseId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncBody<Map<String, dynamic>>(
        load: () async => (await api.get('/api/courses/$courseId')).data as Map<String, dynamic>,
        builder: (context, d, reload) {
          final course = d['course'] as Map<String, dynamic>;
          final modules = (d['modules'] as List?) ?? const [];
          final progress = d['progress'] as Map<String, dynamic>?;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (course['summary'] != null) Text(course['summary'] as String),
              if (progress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: ((progress['progressPercent'] as num?) ?? 0) / 100),
                const SizedBox(height: 4),
                Text('${progress['completedLessons']} of ${progress['totalLessons']} lessons done'),
              ],
              const SizedBox(height: 12),
              for (final m in modules)
                ExpansionTile(
                  title: Text(m['title'] as String? ?? ''),
                  children: [
                    for (final l in (m['lessons'] as List? ?? const []))
                      ListTile(
                        dense: true,
                        leading: Icon(l['completed'] == true ? Icons.check_circle : Icons.circle_outlined),
                        title: Text(l['title'] as String? ?? ''),
                        subtitle: Text(l['type'] as String? ?? ''),
                        trailing: l['accessible'] == true ? null : const Icon(Icons.lock_outline, size: 18),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
