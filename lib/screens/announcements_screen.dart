import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async {
        final res = await api.get('/api/announcements', queryParameters: {'page': 0, 'size': 30});
        return (res.data['content'] as List).where((a) => a['withdrawn'] != true).toList();
      },
      isEmpty: (items) => items.isEmpty,
      emptyText: 'No announcements.',
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = items[i] as Map<String, dynamic>;
            final date = (a['createdAt'] as String? ?? '').split('T').first;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['title'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${a['category'] ?? ''} · $date', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(a['message'] as String? ?? ''),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
