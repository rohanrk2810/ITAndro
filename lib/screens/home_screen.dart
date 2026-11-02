import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../nav_items.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user!;
    final items = navItems.where((i) => user.hasRole(i.roles)).toList();
    final current = items[_index.clamp(0, items.length - 1)];

    return Scaffold(
      appBar: AppBar(title: Text(current.label)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user.fullName),
                accountEmail: Text('${user.roleDisplayName} · ${user.email}'),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      ListTile(
                        leading: Icon(items[i].icon),
                        title: Text(items[i].label),
                        selected: items[i] == current,
                        onTap: () {
                          setState(() => _index = i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () => auth.logout(),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(current.icon, size: 48),
              const SizedBox(height: 12),
              Text('Welcome, ${user.fullName}', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('${current.label} screen is coming next.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
