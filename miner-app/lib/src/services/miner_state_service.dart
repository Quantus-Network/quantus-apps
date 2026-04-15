import 'dart:async';

import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/services/transfer_tracking_service.dart';
import 'package:quantus_miner/src/services/wormhole_address_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;

final _log = log.withTag('MinerState');

/// Centralized state management for the miner app.
///
/// This singleton service owns all miner session state and provides streams
/// for reactive UI updates. It coordinates between:
/// - TransferTrackingService (transfer/balance data)
/// - MinerWalletService (wallet/address data)
/// - WormholeAddressManager (derived addresses)
///
/// Widgets should subscribe to streams rather than maintaining local state copies.
/// The MiningOrchestrator calls lifecycle methods to update state.
class MinerStateService {
  // Singleton
  static final MinerStateService _instance = MinerStateService._internal();
  factory MinerStateService() => _instance;
  MinerStateService._internal();

  // Internal services (all singletons)
  final _transferTrackingService = TransferTrackingService();
  final _walletService = MinerWalletService();
  final _addressManager = WormholeAddressManager();

  // === State ===
  BigInt _balance = BigInt.zero;
  int _unspentCount = 0;
  String? _wormholeAddress;
  String? _secretHex;
  int _currentBlock = 0;
  bool _isSessionActive = false;
  String? _rpcUrl;

  // === Stream Controllers ===
  final _balanceController = StreamController<BalanceState>.broadcast();
  final _blockController = StreamController<int>.broadcast();
  final _sessionController = StreamController<bool>.broadcast();

  // === Public Streams ===
  /// Stream of balance updates. Emits whenever balance changes.
  Stream<BalanceState> get balanceStream => _balanceController.stream;

  /// Stream of block number updates.
  Stream<int> get blockStream => _blockController.stream;

  /// Stream of session active state changes.
  Stream<bool> get sessionActiveStream => _sessionController.stream;

  // === Public Getters ===
  /// Current balance in planck.
  BigInt get balance => _balance;

  /// Number of unspent transfers.
  int get unspentCount => _unspentCount;

  /// Primary wormhole address (SS58 format).
  String? get wormholeAddress => _wormholeAddress;

  /// Secret hex for the wormhole address (needed for proofs).
  String? get secretHex => _secretHex;

  /// Current block number.
  int get currentBlock => _currentBlock;

  /// Whether a mining session is active (node is running).
  bool get isSessionActive => _isSessionActive;

  /// Whether withdrawal is possible (balance > 0 and session active).
  bool get canWithdraw => _isSessionActive && _balance > BigInt.zero;

  // === Lifecycle Methods ===

  /// Start a new mining session.
  ///
  /// Called by MiningOrchestrator when node starts.
  /// Initializes wallet, address manager, and transfer tracking.
  Future<void> startSession({required String rpcUrl}) async {
    _log.i('Starting mining session with RPC: $rpcUrl');
    _rpcUrl = rpcUrl;

    // Load wallet and derive wormhole address
    final keyPair = await _walletService.getWormholeKeyPair();
    if (keyPair != null) {
      _wormholeAddress = keyPair.address;
      _secretHex = keyPair.secretHex;
      _log.i('Loaded wormhole address: $_wormholeAddress');
    } else {
      _log.w('No wallet configured');
    }

    // Initialize address manager
    await _addressManager.initialize();

    // Initialize transfer tracking
    if (_wormholeAddress != null) {
      // Collect all addresses to track (primary + any derived change addresses)
      final allAddresses = _addressManager.allAddressStrings;
      final addressesToTrack = allAddresses.isNotEmpty
          ? allAddresses
          : {_wormholeAddress!};

      await _transferTrackingService.initialize(
        rpcUrl: rpcUrl,
        wormholeAddresses: addressesToTrack,
      );
      await _transferTrackingService.loadFromDisk();

      // Fetch historical transfers from Subsquid for all tracked addresses
      await _fetchHistoricalTransfers(addressesToTrack);
    }

    _isSessionActive = true;
    _sessionController.add(true);

    // Refresh balance immediately
    await _refreshBalance();

    _log.i('Mining session started');
  }

  /// Fetch historical transfers from Subsquid for addresses not already tracked locally.
  ///
  /// This ensures we pick up transfers that occurred while the app was closed.
  Future<void> _fetchHistoricalTransfers(Set<String> addresses) async {
    _log.i(
      'Fetching historical transfers from Subsquid for ${addresses.length} addresses',
    );

    final utxoService = sdk.WormholeUtxoService();

    for (final address in addresses) {
      try {
        // Get transfers from Subsquid
        final transfers = await utxoService.getTransfersTo(address, limit: 100);
        _log.d('Subsquid returned ${transfers.length} transfers for $address');

        // Get locally tracked transfers to avoid duplicates
        final localTransfers = _transferTrackingService.getTransfers(address);
        final localTransferCounts = localTransfers
            .map((t) => t.transferCount)
            .toSet();

        // Add any transfers we don't already have locally
        var added = 0;
        for (final transfer in transfers) {
          if (!localTransferCounts.contains(transfer.transferCount)) {
            _transferTrackingService.addTrackedTransfer(
              TrackedTransfer(
                blockHash: transfer.blockHash,
                blockNumber: transfer.blockNumber,
                transferCount: transfer.transferCount,
                leafIndex: transfer.leafIndex,
                amount: transfer.amount,
                wormholeAddress: transfer.wormholeAddress,
                fundingAccount: transfer.fromAddress,
                timestamp: transfer.timestamp,
              ),
            );
            added++;
          }
        }

        if (added > 0) {
          _log.i(
            'Added $added historical transfers for $address from Subsquid',
          );
        }
      } catch (e) {
        _log.w('Failed to fetch historical transfers for $address: $e');
        // Continue with other addresses even if one fails
      }
    }

    // Save any new transfers to disk
    await _transferTrackingService.saveToDisk();
  }

  /// Stop the current mining session.
  ///
  /// Called by MiningOrchestrator when node stops.
  /// Clears all session state.
  Future<void> stopSession() async {
    _log.i('Stopping mining session');

    _isSessionActive = false;
    _currentBlock = 0;
    _balance = BigInt.zero;
    _unspentCount = 0;

    // Clear transfer tracking (especially important for dev chains)
    await _transferTrackingService.clearAllTransfers();

    // Emit updates
    _sessionController.add(false);
    _blockController.add(0);
    _balanceController.add(
      BalanceState(balance: BigInt.zero, unspentCount: 0, canWithdraw: false),
    );

    _log.i('Mining session stopped');
  }

  /// Handle a chain reset (dev chain restarted).
  ///
  /// Called when block number goes backwards, indicating chain state was reset.
  Future<void> onChainReset() async {
    _log.i('Chain reset detected, clearing state');

    _currentBlock = 0;
    _balance = BigInt.zero;
    _unspentCount = 0;

    // Clear stale transfers
    await _transferTrackingService.clearAllTransfers();

    // Re-initialize if we have RPC URL
    if (_rpcUrl != null && _wormholeAddress != null) {
      final allAddresses = _addressManager.allAddressStrings;
      final addressesToTrack = allAddresses.isNotEmpty
          ? allAddresses
          : {_wormholeAddress!};

      await _transferTrackingService.initialize(
        rpcUrl: _rpcUrl!,
        wormholeAddresses: addressesToTrack,
      );
    }

    // Emit updates
    _blockController.add(0);
    _balanceController.add(
      BalanceState(balance: BigInt.zero, unspentCount: 0, canWithdraw: false),
    );
  }

  // === Called by MiningOrchestrator ===

  /// Process a newly mined block.
  ///
  /// Called by MiningOrchestrator when a new block is detected.
  /// Tracks any transfers in the block and updates balance.
  ///
  /// NOTE: Chain reset detection is handled by MiningOrchestrator, not here.
  /// This method may receive blocks out of order due to async processing,
  /// so we only update _currentBlock if this is a higher block number.
  Future<void> onBlockMined(int blockNumber, String blockHash) async {
    // Update current block only if this is higher (handles out-of-order arrival)
    if (blockNumber > _currentBlock) {
      _currentBlock = blockNumber;
      _blockController.add(blockNumber);
    }

    // Process the block for transfers
    await _transferTrackingService.processBlock(blockNumber, blockHash);

    // Refresh balance (includes checking which transfers are still unspent)
    await _refreshBalance();
  }

  /// Update the current block number without processing transfers.
  ///
  /// Called for blocks that don't need transfer processing (e.g., during sync).
  /// NOTE: Chain reset detection is handled by MiningOrchestrator, not here.
  /// This method only updates the block number for UI display purposes.
  void updateBlockNumber(int blockNumber) {
    // Only update if this is a higher block number to avoid race conditions
    // with onBlockMined() which may have already set a higher block
    if (blockNumber > _currentBlock) {
      _currentBlock = blockNumber;
      _blockController.add(blockNumber);
    }
  }

  // === Called by WithdrawalScreen ===

  /// Get all unspent transfers for withdrawal.
  ///
  /// Returns transfers that haven't been spent yet, filtered by checking
  /// nullifier consumption on-chain.
  Future<List<TrackedTransfer>> getUnspentTransfers() async {
    if (_wormholeAddress == null || _secretHex == null) {
      return [];
    }

    final allUnspent = <TrackedTransfer>[];

    // Get unspent from primary address
    final primaryUnspent = await _transferTrackingService.getUnspentTransfers(
      wormholeAddress: _wormholeAddress!,
      secretHex: _secretHex!,
    );
    allUnspent.addAll(primaryUnspent);

    // Get unspent from any change addresses
    // Take a snapshot of addresses to avoid concurrent modification if
    // a new change address is derived during withdrawal
    final changeAddresses = _addressManager.allAddresses;
    for (final trackedAddr in changeAddresses) {
      if (trackedAddr.address != _wormholeAddress) {
        final changeUnspent = await _transferTrackingService
            .getUnspentTransfers(
              wormholeAddress: trackedAddr.address,
              secretHex: trackedAddr.secretHex,
            );
        allUnspent.addAll(changeUnspent);
      }
    }

    return allUnspent;
  }

  /// Notify that a withdrawal completed successfully.
  ///
  /// This triggers a balance refresh to reflect the spent transfers.
  Future<void> onWithdrawalComplete() async {
    _log.i('Withdrawal completed, refreshing balance');
    await _refreshBalance();
  }

  /// Derive and add a new change address to track.
  ///
  /// Called when a withdrawal needs a change address.
  /// Returns the new change address.
  Future<TrackedWormholeAddress> deriveNextChangeAddress() async {
    final changeAddr = await _addressManager.deriveNextChangeAddress();
    _transferTrackingService.addTrackedAddress(changeAddr.address);
    _log.i('Derived change address: ${changeAddr.address}');
    return changeAddr;
  }

  /// Get the WormholeAddressManager for withdrawal operations.
  ///
  /// This is needed by the withdrawal service to derive change addresses.
  WormholeAddressManager get addressManager => _addressManager;

  // === Internal ===

  /// Refresh the balance by summing unspent transfers.
  Future<void> _refreshBalance() async {
    if (_wormholeAddress == null || _secretHex == null) {
      _balance = BigInt.zero;
      _unspentCount = 0;
      _balanceController.add(
        BalanceState(balance: BigInt.zero, unspentCount: 0, canWithdraw: false),
      );
      return;
    }

    var totalBalance = BigInt.zero;
    var totalCount = 0;

    // Sum primary address unspent
    final primaryUnspent = await _transferTrackingService.getUnspentTransfers(
      wormholeAddress: _wormholeAddress!,
      secretHex: _secretHex!,
    );
    for (final transfer in primaryUnspent) {
      totalBalance += transfer.amount;
      totalCount++;
    }

    // Sum change address unspent
    // Take a snapshot of addresses to avoid concurrent modification
    final changeAddresses = _addressManager.allAddresses;
    for (final trackedAddr in changeAddresses) {
      if (trackedAddr.address != _wormholeAddress) {
        final changeUnspent = await _transferTrackingService
            .getUnspentTransfers(
              wormholeAddress: trackedAddr.address,
              secretHex: trackedAddr.secretHex,
            );
        for (final transfer in changeUnspent) {
          totalBalance += transfer.amount;
          totalCount++;
        }
      }
    }

    _balance = totalBalance;
    _unspentCount = totalCount;

    _balanceController.add(
      BalanceState(
        balance: totalBalance,
        unspentCount: totalCount,
        canWithdraw: _isSessionActive && totalBalance > BigInt.zero,
      ),
    );

    _log.d('Balance refreshed: $totalBalance planck ($totalCount unspent)');
  }

  /// Dispose resources. Call when app is shutting down.
  void dispose() {
    _balanceController.close();
    _blockController.close();
    _sessionController.close();
  }
}

/// Immutable snapshot of balance state.
class BalanceState {
  final BigInt balance;
  final int unspentCount;
  final bool canWithdraw;

  const BalanceState({
    required this.balance,
    required this.unspentCount,
    required this.canWithdraw,
  });

  @override
  String toString() =>
      'BalanceState(balance: $balance, unspent: $unspentCount, canWithdraw: $canWithdraw)';
}
