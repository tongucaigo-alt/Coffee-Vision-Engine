import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_landing_layout.dart';

/// Home actions remain findable while their explanatory captions are hidden.
Finder homeAction(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is AtlasLandingImageButton && widget.label == label,
  ),
  matching: find.byType(TextButton),
);
