import 'ai_contract.dart';

/// Test-build credential, injected from an external build configuration.
/// Never serialize this value into a profile, result, or research export.
const _testKey = String.fromEnvironment('ATLAS_KIMI_TEST_KEY');
const bundledKimiProfile = AiProfile(
  id: 'atlas-bundled-kimi-test-v1',
  name: 'Atlas · Kimi Test',
  url: 'https://api.moonshot.ai/v1',
  model: 'kimi-k2.6',
  provider: AiProvider.direct,
);
bool get bundledKimiEnabled => aiLabEnabled && _testKey.isNotEmpty;
bool isBundledProfile(AiProfile p) => p.id == bundledKimiProfile.id;

String bundledCredential(AiProfile p) {
  if (!bundledKimiEnabled ||
      !isBundledProfile(p) ||
      p.url != bundledKimiProfile.url ||
      p.model != bundledKimiProfile.model ||
      p.provider != AiProvider.direct ||
      !p.noThink) {
    throw const AiFailure('Hazır test bağlantısı değiştirilemez.');
  }
  return _testKey;
}

bool usesKimiInstant(AiProfile p) =>
    p.provider == AiProvider.direct &&
    p.model == 'kimi-k2.6' &&
    p.noThink &&
    p.url == bundledKimiProfile.url;
