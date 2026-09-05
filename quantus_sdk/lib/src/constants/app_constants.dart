class AppConstants {
  static const globalDebug = false;

  static const String appName = 'Quantus Wallet';
  static const String tokenSymbol = 'QTC'; // fetch this from chain eventually
  static const String shareUrl = 'https://linktr.ee/quantusnetwork';
  static const String websiteBaseUrl = 'https://www.quantus.com';
  static const String emailSupport = 'support@quantus.com';
  static const String telegramHandle = '@quantusnetwork';

  // static const List<String> rpcEndpoints = ['http://127.0.0.1:9944']; // local testing
  // static const List<String> graphQlEndpoints = ['http://127.0.0.1:4350/v1/graphql']; // local testing

  static const stillOnTestnet = true;
  static const List<String> rpcEndpoints = [
    'https://a1-planck.quantus.cat',
    'https://a2-planck.quantus.cat',
    'https://matcha-latte.quantus.com',
  ];
  static const List<String> graphQlEndpoints = ['https://sub2.quantus.com/v1/graphql'];

  static const String quersiEndpoint = 'https://qrc-1.quantus.com/api';

  static const String senotiEndpoint = 'https://snt.quantus.com/api';

  static const String explorerEndpoint = 'https://explorer.quantus.com';

  // internal group URL is this (note the /c)
  // https://t.me/c/quantusnetwork/2457
  // removing the c, we get a better preview page though so we use it without c...
  static const String techSupportUrl = 'https://t.me/quantusnetwork/2457';
  static const String termsOfServiceUrl = 'https://www.quantus.com/terms-and-privacy';
  static const String tutorialsAndGuidesUrl = 'https://github.com/Quantus-Network/chain';
  static const String shillQuestsPageUrl = 'https://www.quantus.com/quests/shill';
  static const String raidQuestsPageUrl = 'https://www.quantus.com/quests/raid';
  static const String communityUrl = 'https://t.me/quantusnetwork';
  static const String faucetUrl = 'https://x.com/QuantusNetwork/status/2033738875827589221';
  static const String miningSetupGuideUrl = 'https://docs.quantus.com/guides/mining';
  static const String telemetryUrl = 'https://telemetry.quantus.cat';

  // Development accounts
  static const String crystalAlice = '//Crystal Alice';
  static const String crystalBob = '//Crystal Bob';
  static const String crystalCharlie = '//Crystal Charlie';

  // Shared Preferences keys
  static const String hasWalletKey = 'has_wallet';
  static const String accountIdKey = 'account_id';

  // Reversible time settings
  static const int defaultReversibleTimeSeconds = 600; // 10 minutes

  /// Average Quantus block time in seconds (~12s). Used for mortal-era TTL and block↔time estimates.
  static const int avgBlockTimeSeconds = 12;

  /// Mortal era length for signed transactions, in blocks. Must be a power of
  /// two (the era encoding rounds up); 16 blocks ≈ 3.2 minutes at 12s blocks.
  static const int txMortalEraPeriodBlocks = 16;

  // Digits of precision
  static const int decimals = 12;

  // The chain runtime caps issuance at MAX_SUPPLY = 21_000_000 QTC
  // (runtime/src/lib.rs), so no legitimate amount has more whole digits.
  static const int maxWholeDigits = 8;
  static const int ss58prefix = 189;

  // Runtime the bundled polkadart metadata (lib/generated/planck) was generated
  // from. A signing payload declaring a different spec version may decode
  // against shifted pallet/call indices, so signers warn loudly rather than
  // present a decode they cannot vouch for. Bump both when regenerating.
  static const int bundledSpecVersion = 147;
  static const int bundledTransactionVersion = 6;

  // Runtimes this build's metadata decodes correctly, beyond the one it was
  // generated from. A pair belongs here only once the calls the wallet displays
  // are known to carry identical pallet and call indices — a matching decode is
  // not something to assume across a transaction-version bump.
  static const Set<({int spec, int tx})> compatibleRuntimes = {
    (spec: bundledSpecVersion, tx: bundledTransactionVersion),
  };

  // Reserved account index for the per-wallet encrypted (wormhole) account.
  // Kept high so it never collides with sequential transparent (BIP44) indices;
  // the wormhole keypair derives independently of this value.
  static const int encryptedAccountIndex = 1024;

  // Default sheet height in percentage of screen height
  static const double sendingSheetHeightFraction = 0.72;

  // This starts the hardware wallet flow using a soft wallet - quite useful for debugging
  // hardware wallet flow without using a hardware wallet.
  static const debugHardwareWallet = false;

  // Debug the timing of subsquid and rpc queries
  static const bool debugQueryTiming = false;

  // Always show the home backup nudge regardless of viewed state and balance
  static const bool debugAlwaysShowBackupNudge = false;

  // Home swap action. Off while app review requires swap gone; flip to true to bring it back.
  static const bool showSwapButton = false;

  // Valid SS58 address returned/filled by debug buttons so address-entry flows
  // (send, swap, add hardware account) can be exercised in the simulator where
  // the camera is unavailable.
  static const String debugTestAddress = 'qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG';

  static const String accountSettingsRouteName = 'account-settings';
  static const int highSecurityStepsCount = 3;
}
