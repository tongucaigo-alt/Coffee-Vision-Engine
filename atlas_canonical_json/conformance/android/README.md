# Atlas Canonical JSON Android Conformance

This is a test harness, not an application feature. It verifies the pure-Dart
`atlas_canonical_json` package on a physical Android runtime without adding a
Flutter dependency to the package itself.

Run from this directory with a connected Android device:

```text
flutter drive --profile -d <device-id> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/canonical_json_android_test.dart
```

The harness performs no file I/O, networking, Atlas domain analysis, or user
interaction.
