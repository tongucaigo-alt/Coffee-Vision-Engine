import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:flutter/material.dart';

import 'integration/atlas_k6_controller.dart';
import 'ui/atlas_k6_home_page.dart';

class AtlasK6EndToEndApp extends StatefulWidget {
  const AtlasK6EndToEndApp({required this.dataset, super.key});

  final KnowledgeDatasetSnapshot dataset;

  @override
  State<AtlasK6EndToEndApp> createState() => _AtlasK6EndToEndAppState();
}

class _AtlasK6EndToEndAppState extends State<AtlasK6EndToEndApp> {
  late final AtlasK6Controller _controller = AtlasK6Controller(
    dataset: widget.dataset,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas K6 End-to-End',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E69),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F6F5),
          foregroundColor: Color(0xFF17201E),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFD6DEDB)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
      home: AtlasK6HomePage(controller: _controller),
    );
  }
}
