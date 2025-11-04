class AppConstants {
  static const globalDebug = false;
  static const String appName = 'Quantus Wallet';
  static const String tokenSymbol = 'QU'; // fetch this from chain eventually
  static const String shareUrl = 'https://linktr.ee/quantusnetwork';
  static const String websiteBaseUrl = 'https://www.quantus.com';

  // static const List<String> rpcEndpoints = ['ws://127.0.0.1:9944']; // local testing
  // static const List<String> graphQlEndpoints = ['http://127.0.0.1:4350']; // local testing

  static const List<String> rpcEndpoints = ['https://matcha-latte.quantus.com', 'https://quantu.se'];
  static const List<String> graphQlEndpoints = ['https://subsquid.quantus.com/graphql', 'https://quantu.se/graphql'];

  // local test android use special ip
  // static const String taskMasterEndpoint = 'http://10.0.2.2:3000/api';
  // local test
  // static const String taskMasterEndpoint = 'http://localhost:3000/api';
  static const String taskMasterEndpoint = 'https://quests.quantus.com/api';

  static const String explorerEndpoint = 'https://explorer.quantus.com';
  static const String helpAndSupportUrl = 'https://t.me/quantustechsupport';
  static const String termsOfServiceUrl = 'https://www.quantus.com/terms-and-privacy';
  static const String tutorialsAndGuidesUrl = 'https://github.com/Quantus-Network/chain';
  static const String questsPageUrl = 'https://www.quantus.com/quests';
  static const String communityUrl = 'https://t.me/quantusnetwork';
  static const String faucetBotUrl = 'https://t.me/QuantusFaucetBot';

  // Old Resonance chain endpoints - previous chain
  static const String oldResonanceRpcEndpoint = 'wss://a.t.res.fm:443';
  static const String odlGraphQlEndpoint = 'https://gql.res.fm';

  // Development accounts
  static const String crystalAlice = '//Crystal Alice';
  static const String crystalBob = '//Crystal Bob';
  static const String crystalCharlie = '//Crystal Charlie';

  // Shared Preferences keys
  static const String hasWalletKey = 'has_wallet';
  static const String mnemonicKey = 'mnemonic';
  static const String accountIdKey = 'account_id';

  // Reversible time settings
  static const int defaultReversibleTimeSeconds = 600; // 10 minutes

  // Digits of precision
  static const int decimals = 12;
  static const int ss58prefix = 189;

  // Default sheet height in percentage of screen height
  static const double sendingSheetHeightFraction = 0.72;
}
