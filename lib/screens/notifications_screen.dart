import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../widgets/async_list.dart';

/// Bell for the app bar: shows the unread count, refreshed every minute and after the list is closed.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final res = await context.read<AuthService>().api.dio.get('/api/notifications/unread-count');
      final n = ((res.data as Map)['unread'] as num).toInt();
      if (mounted && n != _unread) setState(() => _unread = n);
    } catch (_) {
      // The badge is a nicety: a failed poll leaves the last count in place.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _refresh();
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Key _refresh = UniqueKey();
  bool _unreadOnly = false;

  Future<void> _markAll() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthService>().api.dio.put('/api/notifications/read-all');
      if (mounted) setState(() => _refresh = UniqueKey());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: _unreadOnly ? 'Show all' : 'Unread only',
            icon: Icon(_unreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() {
              _unreadOnly = !_unreadOnly;
              _refresh = UniqueKey();
            }),
          ),
          IconButton(tooltip: 'Mark all read', icon: const Icon(Icons.done_all), onPressed: _markAll),
        ],
      ),
      body: AsyncBody<List<dynamic>>(
        key: _refresh,
        load: () async => (await api.get('/api/notifications', queryParameters: {'unreadOnly': _unreadOnly, 'size': 50})).data['content'] as List,
        isEmpty: (n) => n.isEmpty,
        emptyText: _unreadOnly ? 'No unread notifications.' : 'No notifications.',
        builder: (context, items, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i] as Map<String, dynamic>;
              final unread = n['read'] != true;
              return ListTile(
                leading: Icon(unread ? Icons.circle : Icons.circle_outlined, size: 12, color: unread ? Theme.of(context).colorScheme.primary : null),
                title: Text(n['title'] as String? ?? '', style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text('${n['message'] ?? ''}\n${(n['createdAt'] as String? ?? '').replaceFirst('T', ' ').split('.').first}'),
                isThreeLine: true,
                onTap: unread
                    ? () async {
                        try {
                          await api.put('/api/notifications/${n['id']}/read');
                          if (mounted) setState(() => _refresh = UniqueKey());
                        } catch (_) {}
                      }
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}
