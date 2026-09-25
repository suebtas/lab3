import 'package:flutter/material.dart';

import 'data/employee_store.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const StartupHrApp());
}

class StartupHrApp extends StatefulWidget {
  const StartupHrApp({super.key});

  @override
  State<StartupHrApp> createState() => _StartupHrAppState();
}

class _StartupHrAppState extends State<StartupHrApp> {
  final EmployeeStore _store = EmployeeStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup HR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
        useMaterial3: true,
        fontFamilyFallback: const ['Noto Sans Thai'],
      ),
      home: HomeScreen(store: _store),
    );
  }
}