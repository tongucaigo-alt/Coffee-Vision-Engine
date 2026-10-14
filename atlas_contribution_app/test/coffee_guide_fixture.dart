import 'dart:io';
import 'package:atlas_contribution_app/src/coffee_guide_store.dart';

/// Existing app regression tests opt out without touching a device/store.
class DismissedGuideStore extends CoffeeGuideStore {
  DismissedGuideStore() : super(Directory('unused-guide-fixture'));
  @override
  Future<CoffeeGuideState> read() async =>
      const CoffeeGuideState(shownCount: 2, dontShowAgain: true);
  @override
  Future<void> save(CoffeeGuideState state) async {}
}
