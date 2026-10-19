import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'screens/home_screen.dart';
import 'screens/brand_motion.dart';
import 'lab/device_lab.dart';
import 'screens/online_catalog_screen.dart';

void main() => runApp(const GogdelyApp());

class GogdelyApp extends StatefulWidget {
  const GogdelyApp({super.key});

  @override
  State<GogdelyApp> createState() => _GogdelyAppState();
}

class _GogdelyAppState extends State<GogdelyApp> {
  ThemeMode themeMode = ThemeMode.system;
  bool _showIntro = kReleaseMode ||
      const bool.fromEnvironment('GOGDELY_SHOW_INTRO', defaultValue: false);

  @override
  Widget build(BuildContext context) {
    const lab = bool.fromEnvironment('GOGDELY_LAB', defaultValue: false);
    const hosted = bool.fromEnvironment('GOGDELY_HOSTED_PWA', defaultValue: false);
    final showLab =
        lab && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);
    final landing = hosted && kIsWeb
        ? OnlineCatalogScreen.fromUri(Uri.base)
        : showLab
            ? DeviceLab(
                child: HomeScreen(
                    themeMode: themeMode,
                    onThemeChanged: (mode) => setState(() => themeMode = mode)))
            : HomeScreen(
                themeMode: themeMode,
                onThemeChanged: (mode) => setState(() => themeMode = mode));
    return MaterialApp(
      title: 'GOGDELY',
      debugShowCheckedModeBanner: false,
      theme: gogdelyTheme(Brightness.light),
      darkTheme: gogdelyTheme(Brightness.dark),
      themeMode: themeMode,
      home: Stack(children: [
        landing,
        if (_showIntro)
          Positioned.fill(
              child: BrandIntro(
                  onFinished: () => setState(() => _showIntro = false))),
      ]),
    );
  }
}
