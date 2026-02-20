import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/services/miner_settings_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';
import 'package:quantus_miner/src/shared/miner_app_constants.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/generated/schrodinger/schrodinger.dart';

final _log = log.withTag('BalanceCard');

class MinerBalanceCard extends StatefulWidget {
  /// Current block number - when this changes, balance is refreshed
  final int currentBlock;

  const MinerBalanceCard({super.key, this.currentBlock = 0});

  @override
  State<MinerBalanceCard> createState() => _MinerBalanceCardState();
}

class _MinerBalanceCardState extends State<MinerBalanceCard> {
  String _walletBalance = 'Loading...';
  String? _walletAddress;
  String _chainId = MinerConfig.defaultChainId;
  Timer? _balanceTimer;
  final _settingsService = MinerSettingsService();
  int _lastRefreshedBlock = 0;

  @override
  void initState() {
    super.initState();

    _loadChainAndFetchBalance();
    // Start automatic polling as backup
    _balanceTimer = Timer.periodic(MinerConfig.balancePollingInterval, (_) {
      _loadChainAndFetchBalance();
    });
  }

  @override
  void didUpdateWidget(MinerBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh balance when block number increases (new block found)
    if (widget.currentBlock > _lastRefreshedBlock && widget.currentBlock > 0) {
      _lastRefreshedBlock = widget.currentBlock;
      _loadChainAndFetchBalance();
    }
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChainAndFetchBalance() async {
    final chainId = await _settingsService.getChainId();
    if (mounted) {
      setState(() => _chainId = chainId);
    }
    await _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    _log.d('Fetching wallet balance for chain: $_chainId');
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final rewardsFile = File('$quantusHome/rewards-address.txt');

      if (await rewardsFile.exists()) {
        final address = (await rewardsFile.readAsString()).trim();

        if (address.isNotEmpty) {
          final chainConfig = MinerConfig.getChainById(_chainId);
          _log.d('Chain: ${chainConfig.id}, rpcUrl: ${chainConfig.rpcUrl}, isLocal: ${chainConfig.isLocalNode}');
          BigInt balance;

          if (chainConfig.isLocalNode) {
            // Use local node RPC for dev chain
            _log.d('Querying balance from local node: ${chainConfig.rpcUrl}');
            balance = await _queryBalanceFromLocalNode(address, chainConfig.rpcUrl);
          } else {
            // Use SDK's SubstrateService for remote chains (dirac)
            _log.d('Querying balance from remote (SDK SubstrateService)');
            balance = await SubstrateService().queryBalance(address);
          }

          _log.d('Balance: $balance');

          if (mounted) {
            setState(() {
              _walletBalance = NumberFormattingService().formatBalance(balance, addSymbol: true);
              _walletAddress = address;
            });
          }
        } else {
          _handleAddressNotSet();
        }
      } else {
        _handleAddressNotSet();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Show helpful message for dev chain when node not running
          if (_chainId == 'dev') {
            _walletBalance = 'Start node to view';
          } else {
            _walletBalance = 'Error';
          }
        });
      }
      _log.w('Error fetching wallet balance', error: e);
    }
  }

  /// Query balance directly from local node using Polkadart
  Future<BigInt> _queryBalanceFromLocalNode(String address, String rpcUrl) async {
    try {
      final provider = Provider.fromUri(Uri.parse(rpcUrl));
      final quantusApi = Schrodinger(provider);

      // Convert SS58 address to account ID using the SDK's crypto
      final accountId = ss58ToAccountId(s: address);

      final accountInfo = await quantusApi.query.system.account(accountId);
      return accountInfo.data.free;
    } catch (e) {
      _log.d('Error querying local node balance: $e');
      // Return zero if node is not running or address has no balance
      return BigInt.zero;
    }
  }

  void _handleAddressNotSet() {
    if (mounted) {
      setState(() {
        _walletBalance = 'Address not set';
        _walletAddress = null;
      });
    }
    _log.w('Rewards address file not found or empty');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: MinerAppConstants.cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.useOpacity(0.1), Colors.white.useOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.useOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.useOpacity(0.2), blurRadius: 20, spreadRadius: 1, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1), // Deep purple
                        Color(0xFF1E3A8A), // Deep blue
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Wallet Balance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.useOpacity(0.9)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _walletBalance,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6366F1), // Deep purple
                letterSpacing: -1,
              ),
            ),
            if (_walletAddress != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.useOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.useOpacity(0.1), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.white.useOpacity(0.5), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _walletAddress!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.useOpacity(0.6),
                          fontFamily: 'Fira Code',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.white.useOpacity(0.5), size: 16),
                      onPressed: () {
                        if (_walletAddress != null) {
                          context.copyTextWithSnackbar(_walletAddress!);
                        }
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
