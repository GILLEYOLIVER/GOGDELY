import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'lab/device_lab.dart';

void main() => runApp(const GogdelyApp());

class GogdelyApp extends StatelessWidget {
  const GogdelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const lab = bool.fromEnvironment('GOGDELY_LAB', defaultValue: false);
    return MaterialApp(
      title: 'GOGDELY — laboratório',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: lab && kIsWeb
          ? const DeviceLab(child: HomeScreen())
          : const HomeScreen(),
    );
  }
}
