import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DpdcBalanceCheckerApp());
}

class DpdcBalanceCheckerApp extends StatelessWidget {
  const DpdcBalanceCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DPDC Balance Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
