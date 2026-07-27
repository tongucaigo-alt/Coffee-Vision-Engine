import 'package:flutter/material.dart';

import 'integration/atlas_m6_controller.dart';
import 'ui/atlas_m6_home_page.dart';

class AtlasM6CameraVisionApp extends StatelessWidget {
  const AtlasM6CameraVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas M6 Camera Vision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF147D64),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFDCE3E0)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
      home: AtlasM6HomePage(controller: AtlasM6Controller()),
    );
  }
}
