import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../widgets/async_list.dart';

/// Students: open jobs and their own applications. Companies, jobs and stages are run from the web app.
class PlacementsScreen extends StatelessWidget {
  const PlacementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.read<AuthService>().user!.role != 'STUDENT') {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('The placement desk is available on the web app.', textAlign: TextAlign.center)),
      );
    }
    return const DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [Tab(text: 'Jobs'), Tab(text: 'My applications')]),
        Expanded(child: TabBarView(children: [_JobsTab(), _ApplicationsTab()])),
      ]),
    );
  }
}

class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  Key _refresh = UniqueKey();

  Future<void> _apply(Map<String, dynamic> job) async {
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Apply: ${job['title']}'),
        content: TextField(controller: note, maxLines: 4, decoration: const InputDecoration(labelText: 'Cover note (optional)', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apply')),
        ],
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (go != true) return;
    try {
      await api.post('/api/jobs/${job['id']}/apply', data: {if (text.isNotEmpty) 'coverNote': text});
      messenger.showSnackBar(const SnackBar(content: Text('Application sent.')));
      if (mounted) setState(() => _refresh = UniqueKey());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not apply.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      key: _refresh,
      load: () async => (await api.get('/api/jobs', queryParameters: {'status': 'OPEN', 'page': 0, 'size': 50})).data['content'] as List,
      isEmpty: (j) => j.isEmpty,
      emptyText: 'No open jobs right now.',
      builder: (context, jobs, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final j = jobs[i] as Map<String, dynamic>;
            final applied = j['myApplicationStage'] != null;
            final eligible = j['eligible'] != false;
            final reasons = (j['ineligibleReasons'] as List?)?.cast<String>() ?? const [];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(j['title'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                  Text('${j['companyName']} · ${j['jobType']}${j['location'] != null ? ' · ${j['location']}' : ''}'),
                  if (j['packageOffered'] != null) Text('Package: ${j['packageOffered']}'),
                  if (j['applicationDeadline'] != null) Text('Apply by ${j['applicationDeadline']}'),
                  if (j['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(j['description'] as String, maxLines: 4, overflow: TextOverflow.ellipsis)),
                  if (!eligible && reasons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Not eligible: ${reasons.join('; ')}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: applied
                        ? Chip(label: Text('Applied · ${j['myApplicationStage']}'))
                        : FilledButton(onPressed: eligible ? () => _apply(j) : null, child: const Text('Apply')),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationsTab extends StatefulWidget {
  const _ApplicationsTab();

  @override
  State<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<_ApplicationsTab> {
  Key _refresh = UniqueKey();

  Future<void> _withdraw(Map<String, dynamic> a) async {
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: Text('${a['jobTitle']} at ${a['companyName']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await api.post('/api/applications/${a['id']}/withdraw');
      if (mounted) setState(() => _refresh = UniqueKey());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not withdraw.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      key: _refresh,
      load: () async => (await api.get('/api/applications/me')).data as List,
      isEmpty: (a) => a.isEmpty,
      emptyText: 'You have not applied to any job yet.',
      builder: (context, apps, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: apps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = apps[i] as Map<String, dynamic>;
            final stage = a['stage'] as String? ?? '';
            final open = stage != 'SELECTED' && stage != 'REJECTED' && stage != 'WITHDRAWN';
            return Card(
              child: ListTile(
                title: Text(a['jobTitle'] as String? ?? ''),
                subtitle: Text('${a['companyName']} · applied ${(a['appliedAt'] as String? ?? '').split('T').first}${a['nextInterviewAt'] != null ? '\nInterview: ${a['nextInterviewAt']}' : ''}${a['offerDetails'] != null ? '\nOffer: ${a['offerDetails']}' : ''}'),
                isThreeLine: a['nextInterviewAt'] != null || a['offerDetails'] != null,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(stage, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (open) GestureDetector(onTap: () => _withdraw(a), child: Text('Withdraw', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
