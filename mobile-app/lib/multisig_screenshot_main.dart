import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/bootstrap/app_bootstrap.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/add_multisig_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/discover_multisig_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_activity_section.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_approve_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_cancel_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_execute_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_signer_picker_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/send/multisig_propose_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/select_recipient_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/settings/add_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_theme.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

const _signerA = 'qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC';
const _signerB = 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7';
const _signerC = 'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y';
const _msigId = 'qzm5QCox8Dp5A3oSXZZYHD8YoYgPz7enykZb6RPUropdCyN5h';
const _msigId2 = 'qzmufPopkLKAwDmTzR5uXg8GMp5sUP48CqafJLUz3fPMSSGSh';
const _recipient = 'qzmTAz3UUw1WGUuVh8nbFmPwcftomduwy6twq6NDR6y9qqtEs';
const _currentBlock = 1000000;

BigInt _tokens(int whole) => BigInt.from(whole) * BigInt.from(10).pow(AppConstants.decimals);

final _accounts = <Account>[
  const Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: _signerA),
  const Account(walletIndex: 0, index: 1, name: 'Account 2', accountId: _signerB),
];

final _msig = MultisigAccount(
  name: 'Treasury',
  accountId: _msigId,
  signers: const [_signerA, _signerB, _signerC],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: _signerA,
  creator: _signerA,
);

final _discovered = <MultisigAccount>[
  _msig,
  MultisigAccount(
    name: 'Multisig 2',
    accountId: _msigId2,
    signers: const [_signerA, _signerC],
    threshold: 2,
    nonce: BigInt.one,
    myMemberAccountId: _signerA,
    creator: _signerC,
  ),
];

MultisigProposal _proposal({
  required int id,
  required MultisigProposalStatus status,
  required List<String> approvals,
  int amountTokens = 25,
  Duration age = const Duration(hours: 5),
}) {
  final now = DateTime.now();
  return MultisigProposal(
    entityId: '$_msigId-$id',
    id: id,
    multisigAddress: _msigId,
    proposer: _signerA,
    createdAt: now.subtract(age),
    updatedAt: now.subtract(const Duration(minutes: 20)),
    pallet: 'Balances',
    call: 'transfer_allow_death',
    recipient: _recipient,
    amount: _tokens(amountTokens),
    expiryBlock: _currentBlock + 28800,
    approvals: approvals,
    deposit: _tokens(1),
    networkFee: BigInt.from(1560000000),
    status: status,
    threshold: 2,
    signerCount: 3,
  );
}

final _awaiting = _proposal(id: 7, status: MultisigProposalStatus.active, approvals: const [_signerA]);
final _readyToExecute = _proposal(
  id: 8,
  status: MultisigProposalStatus.approved,
  approvals: const [_signerA, _signerB],
  amountTokens: 120,
);
final _needsMyApproval = _proposal(
  id: 9,
  status: MultisigProposalStatus.active,
  approvals: const [_signerC],
  amountTokens: 3,
);
final _executed = _proposal(
  id: 5,
  status: MultisigProposalStatus.executed,
  approvals: const [_signerA, _signerB],
  amountTokens: 40,
  age: const Duration(days: 2),
);
final _cancelled = _proposal(
  id: 4,
  status: MultisigProposalStatus.cancelled,
  approvals: const [_signerA],
  amountTokens: 9,
  age: const Duration(days: 3),
);

final _emptyTransactions = CombinedTransactionsList(
  pendingCancellationIds: const {},
  pendingTransactions: const [],
  pendingMultisigCreations: const [],
  pendingMultisigProposals: const [],
  pendingMultisigExecutions: const [],
  pendingMultisigCancellations: const [],
  scheduledReversibleTransfers: const [],
  otherTransfers: const [],
);

void main() async {
  await bootstrap();

  final settings = SettingsService();
  final saved = await settings.getMultisigAccounts();
  final savedIds = saved.map((a) => a.accountId).toSet();
  for (final m in _discovered) {
    if (!savedIds.contains(m.accountId)) await settings.addMultisigAccount(m);
  }
  await settings.setActiveAccount(MultisigDisplayAccount(_msig));

  runApp(
    ProviderScope(
      overrides: [
        accountsProvider.overrideWith(
          (ref) => AccountsNotifier(ref.watch(accountsServiceProvider), initialAccounts: _accounts),
        ),
        multisigCurrentBlockProvider.overrideWith((ref) async => _currentBlock),
        multisigOpenProposalsProvider.overrideWith((ref, msig) async => [_awaiting, _readyToExecute, _needsMyApproval]),
        multisigPastProposalsProvider.overrideWith((ref, msig) async => [_executed, _cancelled]),
        discoveredMultisigsProvider.overrideWith((ref) async => _discovered),
      ],
      child: const _HarnessApp(),
    ),
  );
}

class _HarnessApp extends StatelessWidget {
  const _HarnessApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multisig screens',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.darkTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.dark,
      home: const _MenuScreen(),
    );
  }
}

class _MenuScreen extends StatelessWidget {
  const _MenuScreen();

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Multisig screens'),
      mainContent: ListView(
        children: [
          _MenuButton(
            'Add account menu',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const AddAccountMenuScreen())),
          ),
          _MenuButton(
            'Create multisig',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const AddMultisigScreen())),
          ),
          _MenuButton(
            'Discover multisig',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const DiscoverMultisigScreen())),
          ),
          _MenuButton(
            'Accounts list (multisig rows)',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
          _MenuButton(
            'Multisig details',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => MultisigDetailsScreen(account: _msig))),
          ),
          _MenuButton(
            'Home screen (multisig active)',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const HomeScreen())),
          ),
          _MenuButton(
            'Home: multisig activity',
            (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const _ActivityScreen())),
          ),
          _MenuButton(
            'Propose from multisig (send flow)',
            (c) => startSendFlow(
              c,
              screen: SelectRecipientScreen(strategy: MultisigProposeStrategy(msig: _msig)),
            ),
          ),
          _MenuButton(
            'Proposal detail: needs my approval',
            (c) => showMultisigProposalDetailSheet(c, msig: _msig, proposal: _needsMyApproval),
          ),
          _MenuButton(
            'Proposal detail: awaiting others',
            (c) => showMultisigProposalDetailSheet(c, msig: _msig, proposal: _awaiting),
          ),
          _MenuButton(
            'Proposal detail: ready to execute',
            (c) => showMultisigProposalDetailSheet(c, msig: _msig, proposal: _readyToExecute),
          ),
          _MenuButton(
            'Proposal detail: executed',
            (c) => showMultisigProposalDetailSheet(c, msig: _msig, proposal: _executed),
          ),
          _MenuButton(
            'Proposal detail: cancelled',
            (c) => showMultisigProposalDetailSheet(c, msig: _msig, proposal: _cancelled),
          ),
          _MenuButton('Signer picker sheet', (c) => showMultisigSignerPickerSheet(c, accounts: _accounts)),
          _MenuButton(
            'Approve confirm sheet',
            (c) => showMultisigApproveConfirmSheet(c, msig: _msig, proposal: _needsMyApproval, signer: _accounts.first),
          ),
          _MenuButton(
            'Execute confirm sheet',
            (c) => showMultisigExecuteConfirmSheet(c, msig: _msig, proposal: _readyToExecute),
          ),
          _MenuButton(
            'Cancel confirm sheet',
            (c) => showMultisigCancelConfirmSheet(c, msig: _msig, proposal: _awaiting),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final void Function(BuildContext) onTap;

  const _MenuButton(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => onTap(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: context.themeText.smallParagraph?.copyWith(color: colors.textPrimary)),
        ),
      ),
    );
  }
}

class _ActivityScreen extends StatelessWidget {
  const _ActivityScreen();

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Treasury'),
      mainContent: ListView(
        children: [MultisigActivitySection(msig: _msig, txAsync: AsyncValue.data(_emptyTransactions))],
      ),
    );
  }
}
