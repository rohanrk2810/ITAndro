import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../core/downloads.dart';
import '../widgets/async_list.dart';

/// A student's certificates, each openable as a PDF. Issuing and revoking stay on the web app.
class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  Future<void> _open(BuildContext context, Map<String, dynamic> c) async {
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final problem = await downloadAndOpen(api, '/api/certificates/${c['id']}/pdf', '${c['certificateNo']}.pdf');
      if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not download the certificate.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    if (auth.user!.role != 'STUDENT') {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('Issuing and revoking certificates is available on the web app.', textAlign: TextAlign.center)),
      );
    }
    return AsyncBody<List<dynamic>>(
      load: () async => (await auth.api.dio.get('/api/certificates/me')).data as List,
      isEmpty: (c) => c.isEmpty,
      emptyText: 'No certificates yet. They appear here once the institute issues them.',
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = items[i] as Map<String, dynamic>;
            final revoked = c['status'] == 'REVOKED';
            return Card(
              child: ListTile(
                leading: Icon(Icons.workspace_premium_outlined, color: revoked ? Theme.of(context).colorScheme.error : Colors.amber.shade700),
                title: Text(c['courseTitle'] as String? ?? ''),
                subtitle: Text('${c['certificateNo']} · issued ${c['issueDate']}${revoked ? '\nRevoked: ${c['revokedReason'] ?? ''}' : ''}'),
                isThreeLine: revoked,
                trailing: revoked ? null : const Icon(Icons.download),
                onTap: revoked ? null : () => _open(context, c),
              ),
            );
          },
        ),
      ),
    );
  }
}
