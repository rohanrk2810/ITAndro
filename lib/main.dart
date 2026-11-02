import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/password_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService()..bootstrap();
  runApp(ChangeNotifierProvider.value(value: auth, child: const ItIlmsApp()));
}

class ItIlmsApp extends StatelessWidget {
  const ItIlmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return MaterialApp(
      title: 'IT-ILMS',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB), useMaterial3: true),
      home: !auth.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !auth.signedIn
              ? const LoginScreen()
              : auth.user!.mustChangePassword
                  ? const ChangePasswordScreen(forced: true)
                  : const HomeScreen(),
    );
  }
}
