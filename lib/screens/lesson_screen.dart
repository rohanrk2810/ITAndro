import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';

/// One lesson: text inline, links and videos in the browser, and "Mark complete" for an enrolled student.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson, required this.enrolled});

  final Map<String, dynamic> lesson;
  final bool enrolled;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late bool _done = widget.lesson['completed'] == true;
  bool _busy = false;

  Future<void> _complete() async {
    final api = context.read<AuthService>().api.dio;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await api.post('/api/progress/lessons/${widget.lesson['id']}', data: {'completed': true});
      if (mounted) setState(() => _done = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final accessible = l['accessible'] == true;
    final url = l['contentUrl'] as String?;
    final text = l['textContent'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(l['title'] as String? ?? 'Lesson')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${l['type']}${l['durationMinutes'] != null ? ' · ${l['durationMinutes']} min' : ''}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (!accessible)
            const Text('This lesson is locked. Enrol in the course to open it.')
          else ...[
            if (text != null && text.isNotEmpty) Text(text),
            if (url != null && url.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _open(url),
                icon: Icon(l['type'] == 'VIDEO' ? Icons.play_circle_outline : Icons.open_in_new),
                label: Text(l['type'] == 'VIDEO' ? 'Play video' : 'Open'),
              ),
            ],
            if (l['contentFileRef'] != null && (url == null || url.isEmpty))
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('This file opens on the web app for now.')),
            if (widget.enrolled) ...[
              const SizedBox(height: 24),
              if (_done)
                const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Completed')])
              else
                FilledButton(
                  onPressed: _busy ? null : _complete,
                  child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Mark complete'),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
