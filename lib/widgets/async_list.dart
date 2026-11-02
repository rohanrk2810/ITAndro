import 'package:flutter/material.dart';

import '../core/api_client.dart';

/// Loads once, shows a spinner, an error with Retry, an empty note, or the data.
class AsyncBody<T> extends StatefulWidget {
  const AsyncBody({super.key, required this.load, required this.builder, this.emptyText = 'Nothing here yet.', this.isEmpty});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final String emptyText;
  final bool Function(T data)? isEmpty;

  @override
  State<AsyncBody<T>> createState() => _AsyncBodyState<T>();
}

class _AsyncBodyState<T> extends State<AsyncBody<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(apiErrorMessage(snap.error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _reload, child: const Text('Retry')),
              ]),
            ),
          );
        }
        final data = snap.data as T;
        if (widget.isEmpty?.call(data) ?? false) {
          return Center(child: Text(widget.emptyText));
        }
        return widget.builder(context, data, _reload);
      },
    );
  }
}
