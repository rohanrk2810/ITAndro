import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';
import 'password_screens.dart';

/// Account for everyone; a student also sees the profile the institute keeps on file (read only here).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user!;
    final isStudent = user.role == 'STUDENT';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(user.email),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final r in user.roles) Chip(label: Text(r), visualDensity: VisualDensity.compact),
              ]),
            ]),
          ),
        ),
        if (isStudent) _StudentDetails(api: auth.api.dio),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: auth.logout,
          ),
        ),
      ],
    );
  }
}

class _StudentDetails extends StatelessWidget {
  const _StudentDetails({required this.api});

  final dynamic api;

  static const _fields = <(String, String)>[
    ('studentCode', 'Student ID'),
    ('phone', 'Phone'),
    ('dateOfBirth', 'Date of birth'),
    ('gender', 'Gender'),
    ('highestEducation', 'Education'),
    ('college', 'College'),
    ('graduationYear', 'Graduation year'),
    ('addressLine', 'Address'),
    ('city', 'City'),
    ('state', 'State'),
    ('pincode', 'Pincode'),
    ('guardianName', 'Guardian'),
    ('guardianPhone', 'Guardian phone'),
    ('emergencyContact', 'Emergency contact'),
    ('admissionDate', 'Admission date'),
    ('status', 'Status'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 640,
      child: AsyncBody<Map<String, dynamic>>(
        load: () async => (await api.get('/api/students/me')).data as Map<String, dynamic>,
        builder: (context, s, _) => Card(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final (key, label) in _fields)
                if (s[key] != null && '${s[key]}'.isNotEmpty) ListTile(dense: true, title: Text(label), trailing: Text('${s[key]}')),
            ],
          ),
        ),
      ),
    );
  }
}
