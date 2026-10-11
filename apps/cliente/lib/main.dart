import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const GogdelyApp());

class GogdelyApp extends StatelessWidget {
  const GogdelyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GOGDELY — laboratório',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const HomeScreen(),
      );
}
