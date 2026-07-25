/// Test-only configuration and secrets, injected at build time via `--dart-define`.
///
/// Values come from compile-time environment variables ([String.fromEnvironment]),
/// not from a bundled asset, so test fixtures like the import seed phrase are
/// never shipped inside the production app. The test runner supplies them:
///   * locally, `scripts/patrol_ios_device.sh` passes `--dart-define-from-file=.env.test`;
///   * in CI / Firebase Test Lab, the runner passes `--dart-define=...` from its
///     secret store.
///
/// This keeps the same code path working everywhere while keeping secrets out of
/// the repo and out of release builds.
class TestEnv {
  TestEnv._();

  /// The 24-word mnemonic used by the import-wallet E2E flow.
  static String get importMnemonic => _require('TEST_IMPORT_MNEMONIC');

  /// Known SS58 recipient for the send-flow E2E test (must differ from sender).
  static String get sendRecipientAddress => _require('TEST_SEND_RECIPIENT_ADDRESS');

  static String _require(String key) {
    final value = switch (key) {
      'TEST_IMPORT_MNEMONIC' => const String.fromEnvironment('TEST_IMPORT_MNEMONIC'),
      'TEST_SEND_RECIPIENT_ADDRESS' => const String.fromEnvironment('TEST_SEND_RECIPIENT_ADDRESS'),
      _ => '',
    };
    if (value.isEmpty) {
      throw StateError(
        '$key is not set. Pass it at build time, e.g. '
        '`--dart-define-from-file=.env.test` or `--dart-define=$key=...`.',
      );
    }
    return value;
  }
}
