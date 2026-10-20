import 'package:flutter/material.dart';
import 'features/auth/login_view.dart';
import 'features/home/dashboard_view.dart';

const kCubeBlue = Color(0xFF1565C0);
const kCubeDarkNavy = Color(0xFF0D2D54);
const kCubeCoordBar = Color(0xFF1976D2);
const kCubeNavActive = Color(0xFF1A4A80);
const kCubeIconGray = Color(0xFF424242);
const kCubeIconBlue = Color(0xFF1565C0);
const kCubeFixGreen = Color(0xFF1B5E20);
const kCubeNoFixRed = Color(0xFFD32F2F);

class VerTextApp extends StatelessWidget {
  final bool startLoggedIn;
  const VerTextApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerText',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kCubeBlue,
          primary: kCubeBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kCubeBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: startLoggedIn ? const DashboardView() : const LoginView(),
    );
  }
}
