import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/services/global_history_polling_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/url_utils.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/open_accounts_management_button.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/receive/receive_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_activity_section.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/multisig_propose_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/select_recipient_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_screen.dart';
import 'package:resonance_network_wallet/v2/screens/pos/pos_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/v2/components/global_toast_listener.dart';
import 'package:resonance_network_wallet/v2/screens/home/activity_section.dart';
import 'package:resonance_network_wallet/v2/screens/home/backup_reminder_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    ref.listenManual<TransactionEvent?>(transactionIntentProvider, _onTransactionIntent);
    ref.listenManual<PaymentIntent?>(paymentIntentProvider, _onPaymentIntent);
    ref.listenManual<String?>(sharedAccountIntentProvider, _onSharedIntent);
    ref.listenManual<ProposalIntent?>(proposalIntentProvider, _onProposalIntent);
    ref.listenManual<AsyncValue<DisplayAccount?>>(activeAccountProvider, (_, async) {
      if (async.value == null) return;
      // Accounts may still be loading when an intent arrives on a cold start;
      // retry once they are available.
      _drainPendingIntents();
    });
    // Multisig accounts may still be loading when a proposal intent arrives on a
    // cold start; retry once they are available.
    ref.listenManual<AsyncValue<List<MultisigAccount>>>(multisigAccountsProvider, (_, async) {
      if (async.value == null) return;
      _onProposalIntent(null, ref.read(proposalIntentProvider));
    });
    // Intents are only consumed while unlocked: anything arriving beneath the
    // lock overlay stays queued in its provider and is drained after unlock.
    ref.listenManual<LocalAuthState>(localAuthProvider, (prev, next) {
      if (_isAuthStateUnlocked(next) && (prev == null || !_isAuthStateUnlocked(prev))) {
        _drainPendingIntents();
      }
    });

    Future.microtask(_drainPendingIntents);
  }

  bool _isAuthStateUnlocked(LocalAuthState auth) => auth.isAuthenticated && !auth.isVisuallyLocked;

  bool get _isUnlocked => _isAuthStateUnlocked(ref.read(localAuthProvider));

  /// A send in flight must never be interrupted: intents that would start
  /// another flow or switch the active account are dropped, not queued.
  bool _consumeIfSendInFlight<T>(StateProvider<T?> provider, String label) {
    if (!ref.read(sendFlowActiveProvider)) return false;
    ref.read(provider.notifier).state = null;
    quantusPrint('$label intent ignored: send flow active');
    return true;
  }

  void _drainPendingIntents() {
    if (!mounted) return;
    _onTransactionIntent(null, ref.read(transactionIntentProvider));
    _onPaymentIntent(null, ref.read(paymentIntentProvider));
    _onSharedIntent(null, ref.read(sharedAccountIntentProvider));
    _onProposalIntent(null, ref.read(proposalIntentProvider));
  }

  void _onTransactionIntent(TransactionEvent? _, TransactionEvent? transaction) {
    if (transaction == null || !mounted || !_isUnlocked) return;
    final active = ref.read(activeAccountProvider).value;
    if (active == null) return;
    ref.read(transactionIntentProvider.notifier).state = null;

    showTransactionDetailSheet(context, transaction, active.account.accountId);
  }

  void _onPaymentIntent(PaymentIntent? _, PaymentIntent? payment) {
    if (payment == null || !mounted || !_isUnlocked) return;
    if (_consumeIfSendInFlight(paymentIntentProvider, 'payment')) return;
    final active = ref.read(activeAccountProvider).value;
    // Still loading — the activeAccountProvider listener will retry.
    if (active == null) return;
    ref.read(paymentIntentProvider.notifier).state = null;
    if (active is! RegularAccount) {
      quantusPrint('payment intent: active account cannot send regular transfers');
      context.showWarningToaster(message: ref.read(l10nProvider).sendRegularAccountRequired);
      return;
    }

    startSendFlow(
      context,
      screen: InputAmountScreen(
        strategy: RegularSendStrategy(account: active.account),
        recipientAddress: payment.to,
        initialAmount: payment.amount,
        isPayMode: true,
      ),
    );
  }

  void _onSharedIntent(String? _, String? shared) {
    if (shared == null || !mounted || !_isUnlocked) return;
    if (_consumeIfSendInFlight(sharedAccountIntentProvider, 'shared account')) return;
    ref.read(sharedAccountIntentProvider.notifier).state = null;

    showSharedAddressActionSheet(context, shared);
  }

  /// Handles a proposal push notification tap: selects the owning multisig as
  /// the active account, then opens the detail sheet immediately. The sheet
  /// shows a loader while it resolves the proposal by id.
  Future<void> _onProposalIntent(ProposalIntent? _, ProposalIntent? intent) async {
    if (intent == null || !mounted || !_isUnlocked) return;
    if (_consumeIfSendInFlight(proposalIntentProvider, 'proposal')) return;

    final multisigAccounts = ref.read(multisigAccountsProvider).value;
    // Still loading — the multisigAccountsProvider listener will retry.
    if (multisigAccounts == null) return;

    final msig = multisigAccounts.firstWhereOrNull((m) => m.accountId == intent.multisigAddress);
    // The intent is consumed regardless: a missing multisig is not recoverable
    // by waiting, and we don't want to retry a malformed payload.
    ref.read(proposalIntentProvider.notifier).state = null;
    if (msig == null) {
      quantusPrint('proposal intent: no local multisig for ${intent.multisigAddress}');
      return;
    }

    await ref.read(activeAccountProvider.notifier).setActiveAccount(MultisigDisplayAccount(msig));
    if (!mounted) return;

    showMultisigProposalDetailSheetById(context, msig: msig, proposalId: intent.proposalId);
  }

  Future<void> _refresh() async {
    try {
      await ref.read(globalHistoryPollingServiceProvider).triggerManualRefresh();
    } catch (e) {
      quantusPrint('home refresh error: $e');
      TelemetryService().sendError('Home refresh failed', error: e);
    }
  }

  Future<void> _toggleBalanceHidden() async {
    final notifier = ref.read(isBalanceHiddenProvider.notifier);
    await notifier.setIsBalanceHidden(!ref.read(isBalanceHiddenProvider));
  }

  Future<void> _toggleFlip() async {
    await ref.read(isCurrencyFlippedProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final txAsync = ref.watch(activeAccountTransactionsProvider(TransactionFilter.all));
    final colors = context.colors;
    final text = context.themeText;

    return GlobalToastListener(
      key: const Key(E2EKeys.homeScreen),
      child: accountAsync.when(
        loading: () => const ScaffoldBase(mainContent: Center(child: Loader())),
        error: (e, _) => ScaffoldBase(
          mainContent: Center(
            child: Text(l10n.homeError(e.toString()), style: text.detail?.copyWith(color: colors.textError)),
          ),
        ),
        data: (active) {
          if (active == null) {
            return ScaffoldBase(mainContent: Center(child: Text(l10n.homeNoActiveAccount)));
          }
          return ScaffoldBase.refreshable(
            onRefresh: _refresh,
            slivers: [
              _buildContent(active, colors, text, l10n),
              if (active is MultisigDisplayAccount)
                MultisigActivitySection(msig: active.account, txAsync: txAsync, onRetry: _refresh)
              else
                ActivitySection(txAsync: txAsync, activeAccount: active.account, onRetry: _refresh),
              const SizedBox(height: 58),
            ],
            bottomContent: _buildBottomContent(l10n),
          );
        },
      ),
    );
  }

  Widget _buildContent(DisplayAccount active, AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final backupWalletIndex = ref.watch(backupReminderWalletIndexProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildTopBar(),
        const SizedBox(height: 40),
        _buildBalance(colors, text, l10n),
        const SizedBox(height: 40),
        if (active is MultisigDisplayAccount) ...[
          _buildMultisigActionButtons(l10n, active.account),
          const SizedBox(height: 40),
        ],
        if (active is RegularAccount) ...[_buildActionButtons(l10n, active.account), const SizedBox(height: 40)],
        if (backupWalletIndex != null) ...[
          BackupReminderBanner(walletIndex: backupWalletIndex),
          const SizedBox(height: 40),
        ],
        DottedBorder(
          dashLength: 3,
          gapLength: 5,
          color: colors.borderButton.useOpacity(0.5),
          child: const SizedBox(width: double.infinity, height: 1),
        ),
      ],
    );
  }

  Widget? _buildBottomContent(AppLocalizations l10n) {
    final enablePos = ref.watch(posModeProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final active = ref.watch(activeAccountProvider).value;

    // Encrypted accounts show a persistent privacy notice instead of POS /
    // faucet CTAs (Figma: Encrypted Account Home footer).
    if (isEncryptedAccount(active?.account)) {
      return ScaffoldBaseBottomContent(
        child: PrivateActivityNotice(
          title: l10n.createAccountEncryptedDefaultName,
          subtitle: l10n.privateSendSubtitle,
          showCard: true,
        ),
      );
    }

    if (enablePos) {
      return ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.homeCharge,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosAmountScreen())),
        ),
      );
    }

    return balanceAsync
        .whenData(
          (balance) => balance == BigInt.zero
              ? ScaffoldBaseBottomContent(
                  child: QuantusButton.simple(
                    label: l10n.homeGetTestnetTokens,
                    onTap: () => launchXPost(AppConstants.faucetUrl),
                  ),
                )
              : null,
        )
        .value;
  }

  Widget _buildTopBar() {
    final isBalanceHidden = ref.watch(isBalanceHiddenProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const OpenAccountsManagementButton(),
        Row(
          children: [
            QuantusIconButton.circular(
              style: IconButtonStyle.glass,
              icon: isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              onTap: _toggleBalanceHidden,
              isActive: isBalanceHidden,
              size: IconButtonSize.large,
            ),
            const SizedBox(width: 12),
            QuantusIconButton.circular(
              key: const Key(E2EKeys.homeSettingsButton),
              style: IconButtonStyle.glass,
              icon: Icons.settings_outlined,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreenV2())),
              size: IconButtonSize.large,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalance(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final currencyAsync = ref.watch(balanceDisplayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        currencyAsync.when(
          data: (display) {
            return AmountDisplayWithConversion(
              amountDisplay: display,
              onFlip: _toggleFlip,
              alignment: CrossAxisAlignment.center,
              useQuanLogo: true,
            );
          },
          loading: () => const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Skeleton(width: 200, height: 36)]),
              SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Skeleton(width: 100, height: 18)]),
            ],
          ),
          error: (_, _) => Text(l10n.homeErrorLoadingBalance, style: text.detail?.copyWith(color: colors.textError)),
        ),
      ],
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n, Account account) {
    final isEncrypted = isEncryptedAccount(account);
    const enableSwap = true; // ref.watch(remoteConfigProvider).enableSwap; Override enable swap config for now
    final SendStrategy sendStrategy = isEncrypted
        ? EncryptedSendStrategy(account: account)
        : RegularSendStrategy(account: account);

    final receiveCard = _actionCard(
      iconAsset: 'assets/v2/action_receive.svg',
      label: l10n.homeReceive,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveScreen())),
    );

    final sendCard = _actionCard(
      key: const Key(E2EKeys.homeSendButton),
      iconAsset: 'assets/v2/action_send.svg',
      label: l10n.homeSend,
      onTap: () => startSendFlow(context, screen: SelectRecipientScreen(strategy: sendStrategy)),
    );

    final swapCard = _actionCard(
      iconAsset: 'assets/v2/action_swap.svg',
      label: l10n.homeSwap,
      // Swap is not available for encrypted accounts; keep the button visible
      // but disabled so the layout doesn't change between account types.
      isDisabled: isEncrypted,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SwapScreen())),
    );

    final List<Widget> children = [];

    children.add(receiveCard);
    children.add(const SizedBox(width: 15));
    children.add(sendCard);

    if (enableSwap) {
      children.add(const SizedBox(width: 15));
      children.add(swapCard);
    }

    return Row(children: children);
  }

  Widget _buildMultisigActionButtons(AppLocalizations l10n, MultisigAccount msig) {
    return Row(
      children: [
        _actionCard(
          iconAsset: 'assets/v2/action_receive.svg',
          label: l10n.homeReceive,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveScreen())),
        ),
        const SizedBox(width: 15),
        _actionCard(
          iconAsset: 'assets/v2/action_send.svg',
          label: l10n.multisigProposeTitle,
          onTap: () => startSendFlow(
            context,
            screen: SelectRecipientScreen(strategy: MultisigProposeStrategy(msig: msig)),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    Key? key,
    required String iconAsset,
    required String label,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Expanded(
      child: QuantusButton.simple(
        key: key,
        label: label,
        onTap: onTap,
        isDisabled: isDisabled,
        icon: SvgPicture.asset(iconAsset, width: 24, height: 24),
        iconPlacement: IconPlacement.top,
        padding: const EdgeInsets.all(14),
        variant: ButtonVariant.secondary,
        textStyle: context.themeText.paragraph?.copyWith(color: context.colors.textPrimary.useOpacity(0.8)),
      ),
    );
  }
}
