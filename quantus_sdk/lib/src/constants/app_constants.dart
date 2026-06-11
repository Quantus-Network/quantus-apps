class AppConstants {
  static const globalDebug = false;

  static const String appName = 'Quantus Wallet';
  static const String tokenSymbol = 'QUAN'; // fetch this from chain eventually
  static const String shareUrl = 'https://linktr.ee/quantusnetwork';
  static const String websiteBaseUrl = 'https://www.quantus.com';
  static const String emailSupport = 'support@quantus.com';
  static const String telegramHandle = '@quantusnetwork';

  // static const List<String> rpcEndpoints = ['ws://127.0.0.1:9944']; // local testing
  // static const List<String> graphQlEndpoints = ['http://127.0.0.1:4350']; // local testing

  static const stillOnTestnet = true;
  static const List<String> rpcEndpoints = [
    'https://a1-planck.quantus.cat',
    'https://a2-planck.quantus.cat',
    'https://matcha-latte.quantus.com',
  ];
  static const List<String> graphQlEndpoints = ['https://sub2.quantus.com/v1/graphql'];

  // local test android use special ip
  // static const String taskMasterEndpoint = 'http://10.0.2.2:3000/api';
  // local test
  // static const String taskMasterEndpoint = 'http://localhost:3000/api';
  static const String taskMasterEndpoint = 'https://quests.quantus.com/api';

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

  // Digits of precision
  static const int decimals = 12;
  static const int ss58prefix = 189;

  // Default sheet height in percentage of screen height
  static const double sendingSheetHeightFraction = 0.72;

  // This starts the hardware wallet flow using a soft wallet - quite useful for debugging
  // hardware wallet flow without using a hardware wallet.
  static const debugHardwareWallet = false;

  // Debug the timing of subsquid and rpc queries
  static const bool debugQueryTiming = false;

  // Always show the home backup nudge regardless of viewed state and balance
  static const bool debugAlwaysShowBackupNudge = false;

  static const String accountSettingsRouteName = 'account-settings';
  static const int highSecurityStepsCount = 3;
}
