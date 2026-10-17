import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';
import 'package:resonance_network_wallet/services/swap_harness_service.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/screens/swap/review_swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';

/// Debug builds only: every screen of the swap in and swap out flows, in the
/// order the design walks them. The form and review rows put a stand-in for
/// 1Click in place, so the sheets and screens that follow them run on canned
/// tokens and quotes; the other rows load a simulated swap in the state named,
/// which is neither polled nor kept across restarts.
class SwapDebugScreen extends ConsumerWidget {
  static const title = 'Swap test harness';
  static const subtitle = 'Debug only: walk every swap screen';

  const SwapDebugScreen({super.key});

  static SwapQuote _quote({
    required bool swapOut,
    required Account account,
    required DateTime deadline,
    required bool live,
  }) {
    final unit = BigInt.from(10).pow(AppConstants.decimals);
    return SwapHarnessService.quoteFor(
      from: swapOut ? SwapHarnessService.qtc : SwapHarnessService.usdc,
      to: swapOut ? SwapHarnessService.usdc : SwapHarnessService.qtc,
      amount: swapOut ? unit * BigInt.from(250) : BigInt.from(25000000),
      refundAddress: swapOut ? account.accountId : SwapHarnessService.externalAddress,
      recipient: swapOut ? SwapHarnessService.externalAddress : account.accountId,
      deadline: deadline,
      depositAddress: !live
          ? null
          : swapOut
          ? account.accountId
          : SwapHarnessService.externalDeposit,
    );
  }

  static void _useHarness(WidgetRef ref) =>
      ref.read(swapHarnessServiceProvider.notifier).state ??= SwapHarnessService();

  static (List<_Step>, List<_Step>) _flows(Account account) {
    final now = clock.now();
    final open = now.add(const Duration(minutes: 18));
    final closed = now.subtract(const Duration(minutes: 2));
    final unit = BigInt.from(10).pow(AppConstants.decimals);

    _Step screen(String name, String description, Widget Function() build) => _Step(name, description, (context, ref) {
      _useHarness(ref);
      Navigator.push(context, MaterialPageRoute(builder: (_) => build()));
    });

    _Step swap(
      String name,
      String description,
      String status, {
      bool swapOut = true,
      DateTime? deadline,
      Duration age = const Duration(minutes: 2),
      String? pollError,
      BigInt? amountOut,
      BigInt? refundedAmount,
      String? refundReason,
    }) => _Step(name, description, (context, ref) {
      final quote = _quote(swapOut: swapOut, account: account, deadline: deadline ?? open, live: true);
      final order = SwapOrder(
        quote: quote,
        status: SwapStatus.parse(status),
        amountOut: amountOut,
        refundedAmount: refundedAmount,
        refundReason: refundReason,
        originTxHashes: swapOut ? const [SwapHarnessService.txHash] : const [],
      );
      ref
          .read(activeSwapProvider.notifier)
          .start(
            ActiveSwap(
              order: order,
              accountId: account.accountId,
              accountName: account.name,
              startedAt: now.subtract(age),
              settledAt: order.status.isFinal ? now : null,
              depositByHand: !swapOut,
              depositTxHash: swapOut ? SwapHarnessService.txHash : null,
              depositFee: swapOut ? unit ~/ BigInt.from(50) : null,
              pollError: pollError,
              simulated: true,
            ),
          );
      Navigator.push(context, MaterialPageRoute(builder: (_) => SwapProgressScreen(account: account)));
    });

    final swapIn = [
      screen(
        'Swap form',
        'USDC into QTC; token picker, slippage, refund address, review and deposit follow',
        () => SwapScreen(account: account),
      ),
      screen(
        'Review swap',
        'The dry quote before its deposit address',
        () => ReviewSwapScreen(
          account: account,
          quote: _quote(swapOut: false, account: account, deadline: open, live: false),
        ),
      ),
      swap('Send your deposit', 'Waiting for USDC from another wallet', 'PENDING_DEPOSIT', swapOut: false),
      swap('Swapping', 'USDC arrived, solvers are filling the swap', 'PROCESSING', swapOut: false),
      swap(
        'Swap complete',
        'QTC arrived in the account',
        'SUCCESS',
        swapOut: false,
        amountOut: unit * BigInt.from(249),
      ),
      swap(
        'Deposit window expired',
        'Nothing arrived before the deadline',
        'PENDING_DEPOSIT',
        swapOut: false,
        deadline: closed,
        age: const Duration(minutes: 22),
      ),
      swap(
        'Status unreachable',
        'The status poll keeps failing',
        'PENDING_DEPOSIT',
        swapOut: false,
        pollError: 'SwapApiException(503): Service unavailable',
      ),
    ];

    final swapOut = [
      screen(
        'Swap form',
        'QTC into USDC; recipient address and review follow, the deposit is not sent',
        () => SwapScreen(account: account, swapOut: true),
      ),
      screen(
        'Review swap',
        'The dry quote before its deposit is sent',
        () => ReviewSwapScreen(
          account: account,
          quote: _quote(swapOut: true, account: account, deadline: open, live: false),
        ),
      ),
      swap('Deposit sent, confirming', 'QTC sent, 1Click still waiting for it', 'PENDING_DEPOSIT'),
      swap('Deposit seen', '1Click knows the deposit transaction', 'KNOWN_DEPOSIT_TX'),
      swap('Swapping', 'Solvers are filling the swap', 'PROCESSING'),
      swap(
        'Swap complete',
        'USDC paid out',
        'SUCCESS',
        amountOut: BigInt.from(24900000),
        age: const Duration(minutes: 3),
      ),
      swap(
        'Refunded',
        'Swap failed, QTC sent back',
        'REFUNDED',
        refundedAmount: unit * BigInt.from(250),
        refundReason: 'No liquidity available',
      ),
      swap('Failed', 'Swap failed without a refund yet', 'FAILED'),
      swap('Incomplete deposit', 'Less arrived than was quoted', 'INCOMPLETE_DEPOSIT'),
      swap(
        'Deposit not seen by deadline',
        'The window closed with QTC unseen',
        'PENDING_DEPOSIT',
        deadline: closed,
        age: const Duration(minutes: 22),
      ),
    ];
    return (swapIn, swapOut);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final active = ref.watch(activeAccountProvider).value;
    final account = active is RegularAccount && active.account.signsLocally ? active.account : null;
    final swap = ref.watch(activeSwapProvider);
    final harness = ref.watch(swapHarnessServiceProvider);
    final current = [
      harness == null ? '1Click: real' : '1Click: stand-in',
      swap == null
          ? 'No active swap'
          : '${swap.order.status.wire}${swap.simulated ? ' (simulated)' : ''}, started ${swap.startedAt}',
    ].join(' · ');

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(label.toUpperCase(), style: text.labelData.copyWith(color: colors.textMuted)),
    );

    List<Widget> rows(List<_Step> steps) => [
      for (final step in steps) ...[
        SettingsTappableRow(
          title: step.name,
          subtitle: step.description,
          trailing: SettingsTappableRowUtils.chevron(),
          onTap: () => step.open(context, ref),
        ),
        const SettingsDivider(),
      ],
    ];

    return ScaffoldBase(
      appBar: const V2AppBar(title: title),
      mainContent: account == null
          ? Center(
              child: Text('Select an account that can swap first', style: text.body.copyWith(color: colors.textMuted)),
            )
          : Builder(
              builder: (context) {
                final (swapIn, swapOut) = _flows(account);
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(current, style: text.caption.copyWith(color: colors.textMuted)),
                    ),
                    heading('Swap in flow'),
                    const SettingsDivider(),
                    ...rows(swapIn),
                    heading('Swap out flow'),
                    const SettingsDivider(),
                    ...rows(swapOut),
                  ],
                );
              },
            ),
      bottomContent: swap == null && harness == null
          ? null
          : ScaffoldBaseBottomContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (swap != null)
                    QuantusButton.simple(
                      label: 'Clear active swap',
                      variant: ButtonVariant.staged,
                      onTap: () => ref.read(activeSwapProvider.notifier).clear(),
                    ),
                  if (swap != null && harness != null) const SizedBox(height: 8),
                  if (harness != null)
                    QuantusButton.simple(
                      label: 'Use real 1Click',
                      variant: ButtonVariant.staged,
                      onTap: () => ref.read(swapHarnessServiceProvider.notifier).state = null,
                    ),
                ],
              ),
            ),
    );
  }
}

class _Step {
  final String name;
  final String description;
  final void Function(BuildContext context, WidgetRef ref) open;

  const _Step(this.name, this.description, this.open);
}
