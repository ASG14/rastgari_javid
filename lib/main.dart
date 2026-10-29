
import 'package:flutter/material.dart';

import 'features/auth/presentation/screens/login_screen.dart';

void main() {
  runApp(const RastgariJavidApp());
}

class RastgariJavidApp extends StatelessWidget {
  const RastgariJavidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رستگاری جاوید',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          alignLabelWithHint: true,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
