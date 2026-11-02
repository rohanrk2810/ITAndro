import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../widgets/async_list.dart';

/// Search students and open one's profile (read only). Admissions and edits stay on the web app.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _text = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _query,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, email or ID', border: OutlineInputBorder()),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _text = v.trim()));
          },
        ),
      ),
      Expanded(
        child: AsyncBody<List<dynamic>>(
          key: ValueKey(_text),
          load: () async => (await api.get('/api/students', queryParameters: {'page': 0, 'size': 50, if (_text.isNotEmpty) 'query': _text})).data['content'] as List,
          isEmpty: (s) => s.isEmpty,
          emptyText: 'No students found.',
          builder: (context, students, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = students[i] as Map<String, dynamic>;
                return ListTile(
                  title: Text(s['fullName'] as String? ?? ''),
                  subtitle: Text('${s['studentCode']} · ${s['email']}'),
                  trailing: Text(s['status'] as String? ?? ''),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: (s['id'] as num).toInt(), name: s['fullName'] as String? ?? ''))),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.studentId, required this.name});

  final int studentId;
  final String name;

  static const _fields = <(String, String)>[
    ('studentCode', 'Student ID'),
    ('email', 'Email'),
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
    ('remarks', 'Remarks'),
  ];

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthService>().api.dio;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: AsyncBody<Map<String, dynamic>>(
        load: () async => (await api.get('/api/students/$studentId')).data as Map<String, dynamic>,
        builder: (context, s, _) => ListView(
          children: [
            for (final (key, label) in _fields)
              if (s[key] != null && '${s[key]}'.isNotEmpty) ListTile(dense: true, title: Text(label), trailing: Flexible(child: Text('${s[key]}', textAlign: TextAlign.end))),
          ],
        ),
      ),
    );
  }
}
