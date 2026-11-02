import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';

/// Student: courses with progress and the next fee due. Everyone else: the institute summary, if their role may see it.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return auth.user!.role == 'STUDENT' ? _StudentDashboard(auth: auth) : _StaffDashboard(auth: auth);
  }
}

class _StudentDashboard extends StatelessWidget {
  const _StudentDashboard({required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final api = auth.api.dio;
    return AsyncBody<(List<dynamic>, List<dynamic>)>(
      load: () async {
        final progress = (await api.get('/api/progress/me')).data as List;
        // Fees are optional on the dashboard: a missing plan or a failed call must not hide the courses.
        final fees = await api.get('/api/fees/me').then((r) => r.data as List, onError: (_) => <dynamic>[]);
        return (progress, fees);
      },
      builder: (context, data, reload) {
        final (progress, fees) = data;
        final dueNow = fees.cast<Map<String, dynamic>>().where((p) => p['nextDueDate'] != null).toList();
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Hello, ${auth.user!.fullName}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final p in dueNow)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text('Next fee due ${p['nextDueDate']}'),
                    subtitle: Text('${p['currency'] ?? 'INR'} ${((p['nextDueAmount'] as num?) ?? 0).toStringAsFixed(2)} · outstanding ${((p['outstanding'] as num?) ?? 0).toStringAsFixed(2)}'),
                  ),
                ),
              const SizedBox(height: 4),
              Text('My courses', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (progress.isEmpty) const Text('You are not enrolled in a course yet.'),
              for (final p in progress.cast<Map<String, dynamic>>())
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Course #${p['courseId']} · ${p['status']}'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: ((p['progressPercent'] as num?) ?? 0) / 100),
                      const SizedBox(height: 4),
                      Text('${p['completedLessons']} of ${p['totalLessons']} lessons · ${((p['progressPercent'] as num?) ?? 0).round()}%'),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StaffDashboard extends StatelessWidget {
  const _StaffDashboard({required this.auth});

  final AuthService auth;

  static const _tiles = <(String, String)>[
    ('studentsAdmittedTotal', 'Students admitted'),
    ('enrollmentsTotal', 'Enrollments'),
    ('revenueCollectedTotal', 'Revenue collected'),
    ('installmentsOverdueTotal', 'Overdue installments'),
    ('certificatesIssuedTotal', 'Certificates issued'),
    ('placementsSelectedTotal', 'Placements'),
  ];

  @override
  Widget build(BuildContext context) {
    return AsyncBody<Map<String, dynamic>>(
      load: () async => (await auth.api.dio.get('/api/dashboard/summary')).data as Map<String, dynamic>,
      builder: (context, s, reload) => RefreshIndicator(
        onRefresh: reload,
        child: GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            for (final (key, label) in _tiles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s[key] ?? 0}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(label),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
