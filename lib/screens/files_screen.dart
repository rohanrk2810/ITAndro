import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../core/downloads.dart';
import '../widgets/async_list.dart';

String _size(num bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The caller's own files; tap one to download and open it.
class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async => (await api.get('/api/files/mine', queryParameters: {'page': 0})).data['content'] as List,
      isEmpty: (f) => f.isEmpty,
      emptyText: 'No files yet.',
      builder: (context, files, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final f = files[i] as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(f['filename'] as String? ?? ''),
                subtitle: Text('${f['category']} · ${_size(f['sizeBytes'] as num? ?? 0)} · ${(f['uploadedAt'] as String? ?? '').split('T').first}'),
                trailing: const Icon(Icons.download),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final problem = await downloadAndOpen(api, '/api/files/${f['id']}/download', f['filename'] as String? ?? 'file');
                    if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not download the file.'))));
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
