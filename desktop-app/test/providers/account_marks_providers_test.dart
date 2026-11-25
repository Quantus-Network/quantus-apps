import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_marks_providers.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

void main() {
  final now = DateTime.now();
  late DateTime clock;

  /// A wallet of Main (open), Savings and the Encrypted account unless other
  /// [accounts] are given, and [multisigs], whose indexer is [chain]; its
  /// marks are read until they settle.
  Future<ProviderContainer> wallet(
    WidgetTester tester,
    FakeSendChain chain, {
    List<MultisigAccount> multisigs = const [],
    ActiveSwap? swap,
    List<ActiveSwap> swaps = const [],
    List<Account> accounts = const [mainAccount, savingsAccount, encryptedAccount],
  }) async {
    clock = DateTime(2026, 11, 20, 14, 2);
    final container = ProviderContainer(
      overrides: [
        ...shellOverrides(
          accounts: accounts,
          settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: multisigs)
            ..activeSwaps = [?swap, ...swaps],
          // Read as the chain answers: later, never at once.
          balanceOf: (_) async => oneToken,
          encryptedBalances: {0: oneToken},
          chain: chain,
        ),
        currentTimeProvider.overrideWithValue(() => clock),
        // As the app has it: a swap awaiting its deposit is kept at launch.
        keepsUnpaidSwapsProvider.overrideWithValue(true),
      ],
    );
    container.listen(accountMarksProvider, (_, _) {});
    await settle(tester);
    return container;
  }

  /// Ends [container] inside the test, so nothing it started is still
  /// waiting when the test ends.
  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    container.dispose();
    await tester.pump(const Duration(minutes: 1));
  }

  AccountMark markOf(ProviderContainer container, String accountId) =>
      container.read(accountMarksProvider)[accountId] ?? const AccountMark();

  MultisigProposal proposal(
    String id, {
    MultisigProposalStatus status = MultisigProposalStatus.active,
    List<String> approvals = const [],
    int expiryBlock = 1284220,
  }) => MultisigProposal(
    entityId: id,
    id: id.hashCode,
    multisigAddress: teamMultisig.accountId,
    proposer: 'qzOther',
    createdAt: now,
    updatedAt: now,
    pallet: '',
    call: '',
    recipient: 'qzPayee',
    amount: oneToken,
    expiryBlock: expiryBlock,
    approvals: approvals,
    deposit: oneToken,
    status: status,
    threshold: teamMultisig.threshold,
    signerCount: teamMultisig.signers.length,
  );

  testWidgets('a send on its way counts for the account it leaves, and for no other', (tester) async {
    final container = await wallet(tester, FakeSendChain());

    container
        .read(pendingTransactionsProvider.notifier)
        .add(
          PendingTransactionEvent(
            tempId: 'sending',
            from: savingsAccount.accountId,
            to: 'qzPayee',
            amount: oneToken,
            timestamp: now,
            fee: FakeSendChain.usualFee,
          ),
        );
    await settle(tester);

    expect(markOf(container, savingsAccount.accountId), const AccountMark(inProgress: 1));
    expect(markOf(container, mainAccount.accountId), const AccountMark());
    await close(tester, container);
  });

  testWidgets('a send that failed counts no more, and every account\'s marks can still be read', (tester) async {
    final container = await wallet(tester, FakeSendChain());
    final pending = container.read(pendingTransactionsProvider.notifier)
      ..add(
        PendingTransactionEvent(
          tempId: 'sending',
          from: savingsAccount.accountId,
          to: 'qzPayee',
          amount: oneToken,
          timestamp: now,
          fee: FakeSendChain.usualFee,
        ),
      );
    await settle(tester);
    expect(markOf(container, savingsAccount.accountId), const AccountMark(inProgress: 1));

    // As reconciliation leaves it for a few seconds before taking it away.
    pending.updateState('sending', TransactionState.failed);
    await settle(tester);

    expect(markOf(container, savingsAccount.accountId), const AccountMark());
    expect(markOf(container, mainAccount.accountId), const AccountMark());
    await close(tester, container);
  });

  testWidgets('a swap counts for the account it is from while it runs or awaits its deposit, and for no other', (
    tester,
  ) async {
    final following = [
      ('running', fakeActiveSwap(account: savingsAccount)),
      (
        'awaiting its deposit',
        fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, account: savingsAccount),
      ),
    ];
    for (final (state, swap) in following) {
      final container = await wallet(tester, FakeSendChain(), swap: swap);

      expect(markOf(container, savingsAccount.accountId), const AccountMark(inProgress: 1), reason: state);
      expect(markOf(container, mainAccount.accountId), const AccountMark(), reason: state);
      await close(tester, container);
    }
  });

  testWidgets('a swap that has ended still counts until it is put away: complete, refunded, short-paid, or never paid '
      'in time', (tester) async {
    final ended = [
      ('complete', fakeActiveSwap(status: SwapStatus.success)),
      ('refunded', fakeActiveSwap(status: SwapStatus.refunded)),
      ('short-paid', fakeActiveSwap(swapOut: false, status: SwapStatus.incompleteDeposit)),
      (
        'expired',
        fakeActiveSwap(
          swapOut: false,
          status: SwapStatus.pendingDeposit,
          deadline: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ),
    ];
    for (final (state, swap) in ended) {
      final container = await wallet(tester, FakeSendChain(), swap: swap);
      expect(markOf(container, mainAccount.accountId), const AccountMark(inProgress: 1), reason: state);

      await container.read(activeSwapsProvider.notifier).remove(swap.id);
      expect(markOf(container, mainAccount.accountId), const AccountMark(), reason: '$state, put away');
      await close(tester, container);
    }
  });

  testWidgets('each swap counts, for its own account: two from one count two', (tester) async {
    final container = await wallet(
      tester,
      FakeSendChain(),
      swaps: [
        fakeActiveSwap(),
        fakeActiveSwap(status: SwapStatus.refunded, depositAddress: '0x1111111111111111111111111111111111111111'),
        fakeActiveSwap(account: savingsAccount, depositAddress: '0x2222222222222222222222222222222222222222'),
      ],
    );

    expect(markOf(container, mainAccount.accountId), const AccountMark(inProgress: 2));
    expect(markOf(container, savingsAccount.accountId), const AccountMark(inProgress: 1));
    expect(markOf(container, encryptedAccount.accountId), const AccountMark());
    await close(tester, container);
  });

  testWidgets('a swap whose account the wallet no longer holds counts on every account, a multisig too: each lists '
      'it', (tester) async {
    final container = await wallet(
      tester,
      FakeSendChain(),
      multisigs: [teamMultisig],
      swap: fakeActiveSwap(account: tradingAccount),
    );

    for (final account in <BaseAccount>[mainAccount, savingsAccount, encryptedAccount, teamMultisig]) {
      expect(markOf(container, account.accountId), const AccountMark(inProgress: 1), reason: account.name);
    }
    await close(tester, container);
  });

  testWidgets('an account counts the swaps it lists: its own, and each whose account the wallet no longer holds', (
    tester,
  ) async {
    final container = await wallet(
      tester,
      FakeSendChain(),
      swaps: [
        fakeActiveSwap(),
        fakeActiveSwap(account: tradingAccount, depositAddress: '0x1111111111111111111111111111111111111111'),
      ],
    );

    expect(markOf(container, mainAccount.accountId), const AccountMark(inProgress: 2));
    expect(markOf(container, savingsAccount.accountId), const AccountMark(inProgress: 1));
    for (final account in [mainAccount, savingsAccount, encryptedAccount]) {
      expect(
        markOf(container, account.accountId).inProgress,
        container.read(accountSwapsProvider(account.accountId)).length,
        reason: '${account.name} lists as many',
      );
    }
    await close(tester, container);
  });

  testWidgets("a transfer still scheduled counts for an account never opened, all accounts' read at once", (
    tester,
  ) async {
    final chain = FakeSendChain()
      ..stillScheduled = [
        ReversibleTransferEvent(
          id: 'later',
          from: savingsAccount.accountId,
          to: 'qzPayee',
          amount: oneToken,
          timestamp: now,
          txId: '0xlater',
          status: ReversibleTransferStatus.SCHEDULED,
          scheduledAt: now.add(const Duration(hours: 5)),
          blockNumber: 1,
          blockHash: '0xblock',
        ),
      ];
    final container = await wallet(tester, chain, multisigs: [teamMultisig]);

    expect(markOf(container, savingsAccount.accountId), const AccountMark(inProgress: 1));
    expect(chain.stillScheduledReads, hasLength(1));
    expect(
      chain.stillScheduledReads.single,
      unorderedEquals([mainAccount.accountId, savingsAccount.accountId, teamMultisig.accountId]),
      reason: 'the Encrypted account has no transfers scheduled at an address of its own',
    );
    await close(tester, container);
  });

  testWidgets('a multisig counts its open proposals waiting for a signature from this wallet', (tester) async {
    final chain = FakeSendChain()
      ..openProposals = [
        proposal('waits'),
        proposal('signed', approvals: ['qzMain']),
        proposal('expired', expiryBlock: 1000),
        proposal('executed', status: MultisigProposalStatus.executed),
        proposal('approving'),
      ];
    final container = await wallet(tester, chain, multisigs: [teamMultisig]);
    container
        .read(pendingMultisigApprovalsProvider.notifier)
        .add(
          PendingMultisigApprovalEvent(
            id: 'approving-main',
            multisigAddress: teamMultisig.accountId,
            proposalId: 'approving'.hashCode,
            approverId: 'qzMain',
            submittedAt: now,
          ),
        );
    await settle(tester);

    expect(markOf(container, teamMultisig.accountId), const AccountMark(waitingForSignature: 1));
    expect(chain.openProposalReads, contains(teamMultisig.accountId));
    await close(tester, container);
  });

  group('a proposal ready to execute', () {
    MultisigProposal ready({int expiryBlock = 1284220}) => proposal(
      'ready',
      status: MultisigProposalStatus.approved,
      approvals: ['qzOther', 'qzMain'],
      expiryBlock: expiryBlock,
    );

    testWidgets('waits for this wallet: a signer here executes it', (tester) async {
      final container = await wallet(tester, FakeSendChain()..openProposals = [ready()], multisigs: [teamMultisig]);

      expect(markOf(container, teamMultisig.accountId), const AccountMark(waitingForSignature: 1));
      await close(tester, container);
    });

    testWidgets('waits no more once its execution is on its way', (tester) async {
      final container = await wallet(tester, FakeSendChain()..openProposals = [ready()], multisigs: [teamMultisig]);
      container
          .read(pendingMultisigExecutionsProvider.notifier)
          .add(
            PendingMultisigExecutionEvent(
              tempId: 'executing',
              multisigAddress: teamMultisig.accountId,
              proposalId: 'ready'.hashCode,
              executorId: 'qzMain',
              recipient: 'qzPayee',
              amount: oneToken,
            ),
          );
      await settle(tester);

      expect(markOf(container, teamMultisig.accountId), const AccountMark());
      await close(tester, container);
    });

    testWidgets('waits no more once it has expired', (tester) async {
      final container = await wallet(
        tester,
        FakeSendChain()..openProposals = [ready(expiryBlock: 1000)],
        multisigs: [teamMultisig],
      );

      expect(markOf(container, teamMultisig.accountId), const AccountMark());
      await close(tester, container);
    });

    testWidgets('waits with only a cold wallet signer here: it executes it on its Keystone', (tester) async {
      final cold = MultisigAccount(
        name: 'Cold',
        accountId: 'qzCold',
        signers: const ['qzVault', 'qzOther'],
        threshold: 2,
        nonce: BigInt.zero,
        myMemberAccountId: 'qzVault',
      );
      final container = await wallet(
        tester,
        FakeSendChain()..openProposals = [ready()],
        multisigs: [cold],
        accounts: const [mainAccount, vaultAccount],
      );

      expect(markOf(container, cold.accountId), const AccountMark(waitingForSignature: 1));
      await close(tester, container);
    });

    testWidgets('waits for no wallet without a signer here', (tester) async {
      final elsewhere = MultisigAccount(
        name: 'Elsewhere',
        accountId: 'qzElsewhere',
        signers: const ['qzOther', 'qzStranger'],
        threshold: 2,
        nonce: BigInt.zero,
        myMemberAccountId: 'qzOther',
      );
      final container = await wallet(tester, FakeSendChain()..openProposals = [ready()], multisigs: [elsewhere]);

      expect(markOf(container, elsewhere.accountId), const AccountMark());
      await close(tester, container);
    });
  });

  testWidgets('each sync reads them again: what is still scheduled, and each multisig\'s open proposals', (
    tester,
  ) async {
    final chain = FakeSendChain();
    final container = await wallet(tester, chain, multisigs: [teamMultisig]);
    final scheduledReads = chain.stillScheduledReads.length;
    final proposalReads = chain.openProposalReads.where((id) => id == teamMultisig.accountId).length;

    clock = clock.add(const Duration(minutes: 1));
    container.invalidate(balanceProviderFamily(mainAccount.accountId));
    await settle(tester);

    expect(chain.stillScheduledReads.length, scheduledReads + 1);
    expect(chain.openProposalReads.where((id) => id == teamMultisig.accountId).length, proposalReads + 1);
    await close(tester, container);
  });
}

/// Pumps until what was started has answered: a millisecond at a time, as
/// a provider's rebuild waits for a timer, which a pump of no time does not
/// run.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
