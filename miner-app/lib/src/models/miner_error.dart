/// Types of errors that can occur during mining.
enum MinerErrorType {
  /// The miner process crashed unexpectedly.
  minerCrashed,

  /// The node process crashed unexpectedly.
  nodeCrashed,

  /// Failed to start the miner process.
  minerStartupFailed,

  /// Failed to start the node process.
  nodeStartupFailed,

  /// Lost connection to the miner metrics endpoint.
  metricsConnectionLost,

  /// Lost connection to the node RPC endpoint.
  rpcConnectionLost,

  /// Generic/unknown error.
  unknown,
}

/// Represents an error that occurred during mining operations.
class MinerError {
  /// The type of error.
  final MinerErrorType type;

  /// Human-readable error message.
  final String message;

  /// Process exit code, if applicable.
  final int? exitCode;

  /// The underlying exception, if any.
  final Object? exception;

  /// Stack trace, if available.
  final StackTrace? stackTrace;

  /// When the error occurred.
  final DateTime timestamp;

  MinerError({
    required this.type,
    required this.message,
    this.exitCode,
    this.exception,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a miner crash error.
  factory MinerError.minerCrashed(int exitCode) => MinerError(
    type: MinerErrorType.minerCrashed,
    message: 'Miner process crashed unexpectedly (exit code: $exitCode)',
    exitCode: exitCode,
  );

  /// Create a node crash error.
  factory MinerError.nodeCrashed(int exitCode) => MinerError(
    type: MinerErrorType.nodeCrashed,
    message: 'Node process crashed unexpectedly (exit code: $exitCode)',
    exitCode: exitCode,
  );

  /// Create a miner startup failure error.
  factory MinerError.minerStartupFailed(Object error, [StackTrace? stackTrace]) => MinerError(
    type: MinerErrorType.minerStartupFailed,
    message: 'Failed to start miner: $error',
    exception: error,
    stackTrace: stackTrace,
  );

  /// Create a node startup failure error.
  factory MinerError.nodeStartupFailed(Object error, [StackTrace? stackTrace]) => MinerError(
    type: MinerErrorType.nodeStartupFailed,
    message: 'Failed to start node: $error',
    exception: error,
    stackTrace: stackTrace,
  );

  @override
  String toString() => 'MinerError($type): $message';
}
