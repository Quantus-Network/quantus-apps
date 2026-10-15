import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';

/// Debug builds only: loads a simulated swap in any state the real one can
/// reach, so the badge on the home swap button and every progress screen can
/// be looked at. A simulated swap is neither polled nor kept across restarts.
class SwapDebugScreen extends ConsumerWidget {
  static const title = 'Swap test harness';
  static const subtitle = 'Debug only: simulate a swap in any state';

  static const _usdc = SwapToken(
    assetId: 'nep141:eth-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.omft.near',
    symbol: 'USDC',
    network: 'ETH',
    decimals: 6,
    usdPrice: 1,
  );
  static const _qtc = SwapToken(
    assetId: 'nep141:qtc.omft.near',
    symbol: 'QTC',
    network: SwapToken.quantusNetwork,
    decimals: AppConstants.decimals,
    usdPrice: 0.1,
    isQuantus: true,
  );
  static const _external = '0xa5f3c2b1d4e8a7c9f2b5e6d7c8b9a0f1e2d3c7b9';
  static const _externalDeposit = '0x6b2c9e4d1f8a3b5c7e9d0f2a4b6c8d0e1f3a5b7c';
  static const _txHash = '0x9cbe7d1f3a5b7c9e1f3a5b7c9e1f3a5b7c9e1f3a5b7c9e1f3a5b7c9e1f3a5b7c';

  const SwapDebugScreen({super.key});

  static SwapQuote _quote({required bool swapOut, required Account account, required DateTime deadline}) {
    final unit = BigInt.from(10).pow(AppConstants.decimals);
    return SwapQuote(
      fromToken: swapOut ? _qtc : _usdc,
      toToken: swapOut ? _usdc : _qtc,
      amountIn: swapOut ? unit * BigInt.from(250) : BigInt.from(25000000),
      minAmountIn: swapOut ? unit * BigInt.from(250) : BigInt.from(25000000),
      amountOut: swapOut ? BigInt.from(24860000) : unit * BigInt.from(248),
      minAmountOut: swapOut ? BigInt.from(24611400) : unit * BigInt.from(245),
      amountInUsd: 25,
      amountOutUsd: 24.86,
      slippageBps: 100,
      refundAddress: swapOut ? account.accountId : _external,
      recipient: swapOut ? _external : account.accountId,
      deadline: deadline,
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'simulated',
      signature: 'ed25519:simulated',
      depositAddress: swapOut ? account.accountId : _externalDeposit,
    );
  }

  static List<_Scenario> _scenarios(Account account) {
    final now = clock.now();
    final open = now.add(const Duration(minutes: 18));
    final closed = now.subtract(const Duration(minutes: 2));
    ActiveSwap swap(
      String status, {
      bool swapOut = true,
      DateTime? deadline,
      Duration age = const Duration(minutes: 2),
      String? pollError,
      BigInt? amountOut,
      BigInt? refundedAmount,
      String? refundReason,
    }) {
      final quote = _quote(swapOut: swapOut, account: account, deadline: deadline ?? open);
      final order = SwapOrder(
        quote: quote,
        status: SwapStatus.parse(status),
        amountOut: amountOut,
        refundedAmount: refundedAmount,
        refundReason: refundReason,
        originTxHashes: swapOut ? const [_txHash] : const [],
      );
      return ActiveSwap(
        order: order,
        accountId: account.accountId,
        accountName: account.name,
        startedAt: now.subtract(age),
        settledAt: order.status.isFinal ? now : null,
        depositByHand: !swapOut,
        depositTxHash: swapOut ? _txHash : null,
        depositFee: swapOut ? BigInt.from(10).pow(AppConstants.decimals) ~/ BigInt.from(50) : null,
        pollError: pollError,
        simulated: true,
      );
    }

    return [
      _Scenario('Deposit sent, confirming', 'QTC sent, 1Click still waiting for it', () => swap('PENDING_DEPOSIT')),
      _Scenario('Deposit seen', '1Click knows the deposit transaction', () => swap('KNOWN_DEPOSIT_TX')),
      _Scenario('Swapping', 'Solvers are filling the swap', () => swap('PROCESSING')),
      _Scenario(
        'Completed',
        'USDC paid out',
        () => swap('SUCCESS', amountOut: BigInt.from(24900000), age: const Duration(minutes: 3)),
      ),
      _Scenario(
        'Refunded',
        'Swap failed, QTC sent back',
        () => swap(
          'REFUNDED',
          refundedAmount: BigInt.from(10).pow(AppConstants.decimals) * BigInt.from(250),
          refundReason: 'No liquidity available',
        ),
      ),
      _Scenario('Failed', 'Swap failed without a refund yet', () => swap('FAILED')),
      _Scenario('Incomplete deposit', 'Less arrived than was quoted', () => swap('INCOMPLETE_DEPOSIT')),
      _Scenario(
        'Status unreachable',
        'The status poll keeps failing',
        () => swap('PENDING_DEPOSIT', pollError: 'SwapApiException(503): Service unavailable'),
      ),
      _Scenario(
        'Deposit not seen by deadline',
        'The window closed with QTC unseen',
        () => swap('PENDING_DEPOSIT', deadline: closed, age: const Duration(minutes: 22)),
      ),
      _Scenario(
        'Awaiting deposit',
        'Swap in: waiting for USDC from another wallet',
        () => swap('PENDING_DEPOSIT', swapOut: false),
      ),
      _Scenario(
        'Deposit window expired',
        'Swap in: nothing arrived before the deadline',
        () => swap('PENDING_DEPOSIT', swapOut: false, deadline: closed, age: const Duration(minutes: 22)),
      ),
      _Scenario(
        'Swap in completed',
        'QTC arrived in the account',
        () => swap('SUCCESS', swapOut: false, amountOut: BigInt.from(10).pow(AppConstants.decimals) * BigInt.from(249)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final active = ref.watch(activeAccountProvider).value;
    final account = active is RegularAccount && active.account.signsLocally ? active.account : null;
    final swap = ref.watch(activeSwapProvider);
    final current = swap == null
        ? 'No active swap'
        : '${swap.order.status.wire}${swap.simulated ? ' (simulated)' : ''}, started ${swap.startedAt}';

    return ScaffoldBase(
      appBar: const V2AppBar(title: title),
      mainContent: account == null
          ? Center(
              child: Text('Select an account that can swap first', style: text.body.copyWith(color: colors.textMuted)),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(current, style: text.caption.copyWith(color: colors.textMuted)),
                ),
                const SettingsDivider(),
                for (final scenario in _scenarios(account)) ...[
                  SettingsTappableRow(
                    title: scenario.name,
                    subtitle: scenario.description,
                    trailing: SettingsTappableRowUtils.chevron(),
                    onTap: () {
                      ref.read(activeSwapProvider.notifier).start(scenario.make());
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SwapProgressScreen(account: account)));
                    },
                  ),
                  const SettingsDivider(),
                ],
              ],
            ),
      bottomContent: swap == null
          ? null
          : ScaffoldBaseBottomContent(
              child: QuantusButton.simple(
                label: 'Clear active swap',
                variant: ButtonVariant.staged,
                onTap: () => ref.read(activeSwapProvider.notifier).clear(),
              ),
            ),
    );
  }
}

class _Scenario {
  final String name;
  final String description;
  final ActiveSwap Function() make;

  const _Scenario(this.name, this.description, this.make);
}
