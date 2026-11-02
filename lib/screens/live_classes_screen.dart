import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../widgets/async_list.dart';
import 'live_room_screen.dart';

class LiveClassesScreen extends StatelessWidget {
  const LiveClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')]),
        Expanded(
          child: TabBarView(children: [
            _ClassList(path: '/api/liveclass/upcoming', past: false),
            _ClassList(path: '/api/liveclass/past', past: true),
          ]),
        ),
      ]),
    );
  }
}

class _ClassList extends StatelessWidget {
  const _ClassList({required this.path, required this.past});

  final String path;
  final bool past;

  Future<void> _join(BuildContext context, Map<String, dynamic> s) async {
    final api = context.read<AuthService>().api.dio;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await api.post('/api/liveclass/class-sessions/${s['classSessionId']}/join');
      final join = res.data as Map<String, dynamic>;
      final external = join['externalUrl'] as String?;
      if (external != null && external.isNotEmpty) {
        // Google Meet, Zoom and the like have no room or token here: hand over to the browser or the app.
        await launchUrl(Uri.parse(external), mode: LaunchMode.externalApplication);
        return;
      }
      await navigator.push(MaterialPageRoute(builder: (_) => LiveRoomScreen(join: join)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not join the class.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async => (await api.get(path)).data as List,
      isEmpty: (items) => items.isEmpty,
      emptyText: past ? 'No past classes.' : 'No upcoming live classes.',
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = items[i] as Map<String, dynamic>;
            final joinable = s['joinable'] == true;
            return Card(
              child: ListTile(
                leading: Icon(s['status'] == 'LIVE' ? Icons.sensors : Icons.videocam_outlined, color: s['status'] == 'LIVE' ? Colors.red : null),
                title: Text(s['topic'] as String? ?? s['courseTitle'] as String? ?? 'Live class'),
                subtitle: Text('${s['batchCode']} · ${s['sessionDate']} ${s['startTime']}-${s['endTime']}\n${s['status']}'),
                isThreeLine: true,
                trailing: past
                    ? null
                    : FilledButton(onPressed: joinable ? () => _join(context, s) : null, child: const Text('Join')),
              ),
            );
          },
        ),
      ),
    );
  }
}
