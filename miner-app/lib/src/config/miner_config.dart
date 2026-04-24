/// Centralized configuration for the miner application.
///
/// All ports, timeouts, URLs, and other constants should be defined here
/// rather than scattered throughout the codebase.
class MinerConfig {
  MinerConfig._();

  // ============================================================
  // Network Ports
  // ============================================================

  /// QUIC port for miner-to-node communication
  static const int defaultQuicPort = 9833;

  /// Prometheus metrics port for the external miner
  static const int defaultMinerMetricsPort = 9900;

  /// JSON-RPC port for the node
  static const int defaultNodeRpcPort = 9933;

  /// Prometheus metrics port for the node
  static const int defaultNodePrometheusPort = 9616;

  /// P2P port for node networking
  static const int defaultNodeP2pPort = 30333;

  // ============================================================
  // Timeouts & Retry Configuration
  // ============================================================

  /// Time to wait for graceful process shutdown before force killing
  static const Duration gracefulShutdownTimeout = Duration(seconds: 2);

  /// Initial delay between RPC connection retries
  static const Duration rpcInitialRetryDelay = Duration(seconds: 2);

  /// Maximum delay between RPC connection retries (with exponential backoff)
  static const Duration rpcMaxRetryDelay = Duration(seconds: 10);

  /// Maximum number of RPC connection attempts before giving up
  static const int maxRpcRetries = 30;

  /// Number of consecutive metrics failures before resetting hashrate to zero
  static const int maxConsecutiveMetricsFailures = 5;

  /// Delay after killing a process before checking if port is free
  static const Duration portCleanupDelay = Duration(seconds: 1);

  /// Delay after process cleanup before continuing
  static const Duration processCleanupDelay = Duration(seconds: 2);

  /// Timeout for force kill operations
  static const Duration forceKillTimeout = Duration(seconds: 5);

  /// Delay for process verification after kill
  static const Duration processVerificationDelay = Duration(milliseconds: 500);

  // ============================================================
  // Polling Intervals
  // ============================================================

  /// How often to poll external miner metrics endpoint
  static const Duration metricsPollingInterval = Duration(seconds: 1);

  /// How often to poll node Prometheus metrics (for target block)
  static const Duration prometheusPollingInterval = Duration(seconds: 3);

  /// How often to check for binary updates
  static const Duration binaryUpdatePollingInterval = Duration(minutes: 30);

  /// How often to poll chain RPC for peer count and block info
  static const Duration chainRpcPollingInterval = Duration(seconds: 1);

  /// How often to poll wallet balance (backup timer)
  static const Duration balancePollingInterval = Duration(seconds: 30);

  // ============================================================
  // Hardware Detection
  // ============================================================

  /// Maximum number of GPU devices to probe for during detection
  static const int maxGpuProbeCount = 8;

  // ============================================================
  // URLs & Endpoints
  // ============================================================

  /// Returns the miner metrics URL for a given port
  static String minerMetricsUrl(int port) => 'http://127.0.0.1:$port/metrics';

  /// Returns the node RPC URL for a given port
  static String nodeRpcUrl(int port) => 'http://127.0.0.1:$port';

  /// Returns the node Prometheus metrics URL for a given port
  static String nodePrometheusUrl(int port) => 'http://127.0.0.1:$port/metrics';

  /// Default localhost address for connections
  static const String localhost = '127.0.0.1';

  // ============================================================
  // Chain Configuration
  // ============================================================

  /// Available chain IDs
  static const List<ChainConfig> availableChains = [
    ChainConfig(
      id: 'dev',
      displayName: 'Development',
      description: 'Local development chain',
      rpcUrl: 'http://127.0.0.1:9933',
      subsquidUrl: 'http://127.0.0.1:4350/graphql',
      isDefault: false,
    ),
    ChainConfig(
      id: 'dirac',
      displayName: 'Dirac',
      description: 'Dirac testnet',
      rpcUrl: 'https://a1-dirac.quantus.cat',
      subsquidUrl: 'https://subsquid.quantus.com/blue/graphql',
      isDefault: false,
    ),
    ChainConfig(
      id: 'planck',
      displayName: 'Planck Testnet',
      description: 'Planck testnet',
      rpcUrl: 'https://a1-planck.quantus.cat',
      subsquidUrl: 'http://127.0.0.1:4000/graphql', // Local Subsquid for testing
      isDefault: true,
    ),
  ];

  /// Get chain config by ID, returns dev chain if not found
  static ChainConfig getChainById(String id) {
    return availableChains.firstWhere((chain) => chain.id == id, orElse: () => availableChains.first);
  }

  /// The default chain ID
  static String get defaultChainId => availableChains.firstWhere((c) => c.isDefault).id;

  // ============================================================
  // Process Names (for cleanup)
  // ============================================================

  /// Node binary name (without extension)
  static const String nodeBinaryName = 'quantus-node';

  /// Miner binary name (without extension)
  static const String minerBinaryName = 'quantus-miner';

  /// Node binary name with Windows extension
  static String get nodeBinaryNameWindows => '$nodeBinaryName.exe';

  /// Miner binary name with Windows extension
  static String get minerBinaryNameWindows => '$minerBinaryName.exe';

  // ============================================================
  // Logging
  // ============================================================

  /// Maximum number of log lines to keep in memory
  static const int maxLogLines = 200;

  /// Initial lines to print before filtering kicks in
  static const int initialLinesToPrint = 50;

  // ============================================================
  // Port Range for Finding Alternatives
  // ============================================================

  /// Number of ports to try when finding an alternative
  static const int portSearchRange = 10;
}

/// Configuration for a blockchain network.
///
/// Named ChainConfig to avoid conflict with ChainInfo in chain_rpc_client.dart
class ChainConfig {
  final String id;
  final String displayName;
  final String description;
  final String rpcUrl;
  final String? subsquidUrl;
  final bool isDefault;

  const ChainConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.rpcUrl,
    this.subsquidUrl,
    this.isDefault = false,
  });

  /// Whether this chain uses the local node RPC
  bool get isLocalNode => rpcUrl.contains('127.0.0.1') || rpcUrl.contains('localhost');

  @override
  String toString() => 'ChainConfig(id: $id, displayName: $displayName, rpcUrl: $rpcUrl)';
}
