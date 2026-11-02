import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';

String _money(Object? v, String currency) => '$currency ${((v as num?) ?? 0).toStringAsFixed(2)}';

Color _stateColor(BuildContext context, String state) {
  switch (state) {
    case 'PAID':
      return Colors.green;
    case 'OVERDUE':
      return Theme.of(context).colorScheme.error;
    case 'DUE':
    case 'PARTLY_PAID':
      return Colors.orange;
    default:
      return Theme.of(context).colorScheme.outline;
  }
}

/// A student's own fees: totals, installments and payments. Staff finance desks stay on the web app.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    if (!auth.user!.hasRole(['STUDENT'])) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('The finance desk is available on the web app.', textAlign: TextAlign.center),
        ),
      );
    }
    final api = auth.api.dio;
    return AsyncBody<List<dynamic>>(
      load: () async => (await api.get('/api/fees/me')).data as List,
      isEmpty: (plans) => plans.isEmpty,
      emptyText: 'No fee plan yet.',
      builder: (context, plans, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [for (final p in plans) _PlanCard(plan: p as Map<String, dynamic>)],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final cur = plan['currency'] as String? ?? 'INR';
    final installments = (plan['installments'] as List?) ?? const [];
    final payments = (plan['payments'] as List?) ?? const [];
    final text = Theme.of(context).textTheme;
    final nextDue = plan['nextDueDate'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Fee plan', style: text.titleMedium),
            Chip(label: Text(plan['status'] as String? ?? ''), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          _row('Net fee', _money(plan['netFee'], cur)),
          _row('Paid', _money(plan['paid'], cur)),
          _row('Outstanding', _money(plan['outstanding'], cur), bold: true),
          if (((plan['overdue'] as num?) ?? 0) > 0)
            _row('Overdue', _money(plan['overdue'], cur), color: Theme.of(context).colorScheme.error),
          if (nextDue != null) _row('Next due', '$nextDue · ${_money(plan['nextDueAmount'], cur)}'),
          if (installments.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Installments', style: text.titleSmall),
            for (final i in installments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('#${i['installmentNo']} · due ${i['dueDate']}'),
                subtitle: Text('${_money(i['paid'], cur)} of ${_money(i['amount'], cur)}'),
                trailing: Text(i['state'] as String? ?? '', style: TextStyle(color: _stateColor(context, i['state'] as String? ?? ''), fontWeight: FontWeight.w600)),
              ),
          ],
          if (payments.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Payments', style: text.titleSmall),
            for (final p in payments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${_money(p['amount'], cur)} · ${p['method']}'),
                subtitle: Text('${p['paymentDate']} · receipt ${p['receiptNo']}'),
                trailing: p['status'] == 'REVERSED' ? const Text('Reversed') : null,
              ),
          ],
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color)),
        ]),
      );
}
