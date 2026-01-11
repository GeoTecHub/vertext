import 'package:flutter/material.dart';
import 'features/auth/login_view.dart';
import 'features/home/home_view.dart';

class VerTextApp extends StatelessWidget {
  final bool startLoggedIn;
  const VerTextApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Data',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: startLoggedIn ? const HomeView() : const LoginView(),
    );
  }
}
