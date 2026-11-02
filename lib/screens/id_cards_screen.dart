import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../core/api_client.dart';
import '../core/downloads.dart';
import '../widgets/async_list.dart';

/// The signed-in person's own ID cards, with the photo and a PDF. Issuing and revoking stay on the web app.
class IdCardsScreen extends StatelessWidget {
  const IdCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async => (await api.get('/api/id-cards/me')).data as List,
      isEmpty: (c) => c.isEmpty,
      emptyText: 'No ID card has been issued to you yet.',
      builder: (context, cards, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [for (final c in cards.cast<Map<String, dynamic>>()) _CardView(card: c, api: api)],
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.api});

  final Map<String, dynamic> card;
  final Dio api;

  Future<Uint8List?> _photo() async {
    if (card['hasPhoto'] != true) return null;
    try {
      final res = await api.get<List<int>>('/api/id-cards/${card['id']}/photo', options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(res.data!);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = card['status'] as String? ?? '';
    final valid = status == 'ISSUED';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            FutureBuilder<Uint8List?>(
              future: _photo(),
              builder: (context, snap) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 104,
                  child: snap.data != null
                      ? Image.memory(snap.data!, fit: BoxFit.cover)
                      : const ColoredBox(color: Colors.black12, child: Icon(Icons.person, size: 44, color: Colors.black38)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card['fullName'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                Text('${card['personType']}${card['designation'] != null ? ' · ${card['designation']}' : ''}'),
                if (card['personCode'] != null) Text('ID ${card['personCode']}'),
                if (card['batchName'] != null) Text(card['batchName'] as String),
                const SizedBox(height: 4),
                Text('Card ${card['cardNo']}', style: Theme.of(context).textTheme.bodySmall),
                Text('Valid until ${card['validUntil']}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Chip(
              label: Text(status),
              backgroundColor: valid ? Colors.green.shade100 : Theme.of(context).colorScheme.errorContainer,
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            if (valid)
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final problem = await downloadAndOpen(api, '/api/id-cards/${card['id']}/pdf', '${card['cardNo']}.pdf');
                    if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not download the ID card.'))));
                  }
                },
              ),
          ]),
          if (card['revokedReason'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Revoked: ${card['revokedReason']}')),
        ]),
      ),
    );
  }
}
