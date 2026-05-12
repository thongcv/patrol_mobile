import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/location_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PatrolMobileApp());
}

class PatrolMobileApp extends StatefulWidget {
  const PatrolMobileApp({super.key});

  @override
  State<PatrolMobileApp> createState() => _PatrolMobileAppState();
}

class _PatrolMobileAppState extends State<PatrolMobileApp> {
  Locale _locale = const Locale('vi');

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF2563EB),
        surface: const Color(0xFF0F172A),
      ),
    );

    return MaterialApp(
      title: 'SPS Patrol',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: LocationGateScreen(
        locale: _locale,
        onLocaleChanged: (Locale l) => setState(() => _locale = l),
      ),
    );
  }
}
