import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/notice_box.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_form_parts.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/send/send_summary.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_review.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_screen_logic.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/send/wormhole_steps.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/explorer_url.dart';

/// The steps of the Send sheet. Only a private send has the proving.
enum _Step { form, review, proving, receipt }

/// The Send sheet: a form for who is paid and how much, a review of the send
/// before the system is asked to approve it, and a receipt once it has been
/// handed to the network. A private send from the Encrypted account builds
/// its proofs first, which takes a while: the sheet shows how far that is,
/// and it can be stopped.
///
/// On a multisig the sheet is Propose: the same steps for a transfer the
/// multisig's other signers must approve, which a member's account of this
/// wallet signs and pays for.
///
/// The send leaves the account the sheet opened on. Its flow, a first fee
/// quote with it, was started by the press that opened the sheet.
class SendSheet extends ConsumerStatefulWidget {
  const SendSheet({super.key});

  static const addressFieldKey = Key('send-address');
  static const amountFieldKey = Key('send-amount');
  static const pasteKey = Key('send-paste');
  static const maxKey = Key('send-max');
  static const retryFeeKey = Key('send-retry-fee');
  static const costProblemKey = Key('send-cost-problem');
  static const cancelKey = Key('send-cancel');
  static const reviewKey = Key('send-review');
  static const backKey = Key('send-back');
  static const sendKey = Key('send-send');
  static const explorerKey = Key('send-explorer');
  static const shareKey = Key('send-share');
  static const doneKey = Key('send-done');
  static const privateNoticeKey = Key('send-private-notice');
  static const stopKey = Key('send-stop');
  static const closeKey = Key('send-close');

  /// The line of a private send's step, by the number the proving reports
  /// the step under.
  static Key stepKey(int step) => ValueKey('send-step-$step');

  /// The row, on the receipt, of the [index]th transaction of a private send
  /// that took several.
  static Key transactionKey(int index) => ValueKey('send-transaction-$index');

  /// The list of the addresses paid before.
  static const recentsKey = Key('send-recents');

  /// The row of [address] among the addresses paid before.
  static Key recentKey(String address) => ValueKey('send-recent-$address');

  /// How many of the addresses paid before the form offers.
  static const recentsShown = 4;

  @override
  ConsumerState<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<SendSheet> {
  /// The sheet opens on the active account and stays on it while it is open.
  late final BaseAccount _account;
  late final SendStrategy _strategy;

  /// The account that signs a proposal and pays what it costs; null for a
  /// send, which the account it leaves pays.
  late final Account? _signer;

  final _address = TextEditingController();
  final _amountText = TextEditingController();
  final _addressFocus = FocusNode();
  final _amountFocus = FocusNode();

  /// Holds the keyboard's focus on the steps that have no field, so the
  /// sheet's keys still reach it.
  final _stepFocus = FocusNode(skipTraversal: true);

  _Step _step = _Step.form;

  /// The addresses paid before that the form offers.
  List<String> _recents = const [];

  /// What is known of the address in the field: whether it is one at all,
  /// then the send's own verdict on it, which may take a while or fail.
  bool _isAddress = false;
  RecipientBlock? _block;
  bool _isChecking = false;
  bool _checkFailed = false;
  String _lastAddress = '';
  StreamSubscription<RecipientBlock?>? _blockSubscription;

  /// The read of the clipboard that Paste is waiting on, if any.
  Object? _pendingPaste;

  /// Who the review opened on. From then on this is who is paid, whatever
  /// becomes of the field.
  String? _reviewedRecipient;

  /// The amount in the field, zero while it holds none or one that cannot
  /// be read.
  BigInt _amount = BigInt.zero;
  bool _amountUnreadable = false;

  /// The box that sends the maximum is ticked: the amount is whatever the
  /// fee leaves of the balance, and follows it. The field is locked until
  /// the box is unticked.
  bool _isMax = false;

  /// The fee the review opened with.
  SendFee? _openedWith;

  /// The system is being asked, or the send is on its way to the network:
  /// neither can be interrupted.
  bool _isSending = false;

  /// Why the last press of Send sent nothing.
  String? _error;

  /// The amount a private send is proving.
  BigInt? _provingAmount;

  /// The submitted send, and its figures as the review showed them last.
  SendTerminalContent? _submitted;
  List<SendReviewRow> _submittedRows = const [];

  /// What becomes of the submitted send's transaction, where its receipt
  /// waits to know: a proposal's, which is no proposal until the chain has
  /// created it.
  ProviderListenable<SendConfirmation>? _confirmation;

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeAccountProvider).value;
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final strategy = sendStrategyFor(active, accounts: accounts);
    if (active == null || strategy == null) {
      throw StateError('A send was opened on an account this app cannot send from.');
    }
    _account = active.account;
    _strategy = strategy;
    _signer = sendSigner(strategy, accounts);
    _address.addListener(_onAddressChanged);
    _addressFocus.requestFocus();
    unawaited(_loadRecents());
  }

  @override
  void dispose() {
    _blockSubscription?.cancel();
    _address.dispose();
    _amountText.dispose();
    _addressFocus.dispose();
    _amountFocus.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ who is paid

  String get _typedAddress => _address.text.trim();

  /// Who is paid: the address in the field while the form is open, then the
  /// one the review opened on.
  String get _recipient => _reviewedRecipient ?? _typedAddress;

  /// The recipient can be paid: the address in the field passed its checks,
  /// as the one under review did before the review opened.
  bool get _recipientAccepted =>
      _reviewedRecipient != null || (_isAddress && _block == null && !_isChecking && !_checkFailed);

  Future<void> _loadRecents() async {
    final all = await ref.read(recentAddressesServiceProvider).getAddresses();
    if (!mounted) return;
    setState(() {
      _recents = all.where((a) => a != _strategy.sourceAccountId).take(SendSheet.recentsShown).toList();
    });
  }

  /// The controller also tells of selection changes, so an unchanged address
  /// is only looked up again when its last check failed.
  void _onAddressChanged() {
    final address = _typedAddress;
    if (address == _lastAddress && !_checkFailed) return;
    _lastAddress = address;
    _blockSubscription?.cancel();
    final isAddress = address.isNotEmpty && ref.read(substrateServiceProvider).isValidSS58Address(address);
    setState(() {
      _isAddress = isAddress;
      _block = null;
      _isChecking = isAddress;
      _checkFailed = false;
    });
    if (!isAddress) return;
    // Verdicts come as the send has them, the check against its own account
    // first. The latest stands; any edit cancels the subscription.
    _blockSubscription = _strategy
        .recipientBlock(ref, address)
        .listen(
          (block) {
            if (!mounted) return;
            setState(() {
              _block = block;
              _isChecking = false;
            });
          },
          onError: (Object e) {
            quantusPrint('The check of a send\'s recipient failed: $e');
            if (!mounted) return;
            // A check that failed keeps the send closed.
            setState(() {
              _isChecking = false;
              _checkFailed = true;
            });
          },
        );
  }

  Future<void> _paste() async {
    final paste = _pendingPaste = Object();
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    // An answer that comes once the form was left, or after a later press of
    // Paste, is no longer the one that was asked for.
    if (!mounted || paste != _pendingPaste) return;
    _pendingPaste = null;
    if (text.isEmpty) return;
    _address.text = text;
  }

  /// What is wrong with the address in the field, if anything.
  String? _addressProblem(AppLocalizations l10n) {
    if (_recipient.isEmpty) return null;
    if (!_isAddress) return l10n.desktopSendAddressInvalid;
    if (_checkFailed) return l10n.sendRecipientCheckFailedMessage;
    return switch (_block) {
      RecipientBlock.self => l10n.desktopSendAddressSelf,
      RecipientBlock.oneClickDeposit => l10n.encryptedSendNearIntentsDescription,
      null => null,
    };
  }

  // --------------------------------------------------------------- how much

  /// The send moves the whole balance in one call.
  bool get _sendAll => _isMax && _strategy.supportsSendAll;

  /// Who the send's fee is priced to. Until there is someone to pay, that
  /// is the account itself: a transfer costs the same whoever it pays.
  String get _pricedRecipient => _recipientAccepted ? _recipient : (_strategy.sourceAccountId ?? '');

  ProviderListenable<SendFeeState> get _feeProvider =>
      _strategy.feeProvider(recipient: _pricedRecipient, amount: _amount);

  /// Prices a send of [amount]. Until there is someone to pay it is priced
  /// to the account itself: a transfer costs the same whoever it pays.
  void _requestFee(BigInt amount, {bool immediate = false}) {
    final recipient = _recipientAccepted ? _recipient : _strategy.sourceAccountId;
    if (recipient == null) return;
    _strategy.requestFee(ref.read, recipient: recipient, amount: amount, sendAll: _sendAll, immediate: immediate);
  }

  bool _feeApplies(SendFeeState feeState) {
    final fee = feeState.fee;
    return fee != null && feeState.settled && _strategy.feeApplies(fee, amount: _amount, sendAll: _sendAll);
  }

  BigInt _maxSendable(SendFee? fee) => SendScreenLogic.calculateMaxSendableAmount(
    balance: ref.read(_strategy.spendableBalanceProvider).value ?? BigInt.zero,
    networkFee: _strategy.feeChargedToBalance(fee),
  );

  String _amountAsTyped(BigInt amount) => amount == BigInt.zero
      ? ''
      : ref
            .read(numberFormattingServiceProvider)
            .formatBalance(amount, smartDecimals: AppConstants.decimals, addThousandsSeparators: false);

  /// Puts [amount] in the field, as a tick of the maximum and a fee that
  /// moves a maximum send do.
  void _setAmount(BigInt amount) {
    if (amount == _amount) return;
    _amountText.text = _amountAsTyped(amount);
    setState(() {
      _amount = amount;
      _amountUnreadable = false;
    });
  }

  void _onAmountChanged(String text) {
    final amount = ref.read(numberFormattingServiceProvider).parseAmount(text);
    setState(() {
      _amount = amount ?? BigInt.zero;
      _amountUnreadable = amount == null;
    });
    if (_amount > BigInt.zero) _requestFee(_amount);
  }

  /// Ticked, the send is of everything that can be spent, and the amount
  /// cannot be typed over. A send that can move the whole balance in one
  /// call prices that call at once, and the amount follows its fee as it
  /// lands. Unticked, the amount stays as it is, an amount like any other
  /// from then on.
  void _setMax(bool isMax) {
    setState(() => _isMax = isMax);
    if (isMax) _setAmount(_maxSendable(ref.read(_feeProvider).fee));
    if (_amount > BigInt.zero) _requestFee(_amount, immediate: true);
  }

  /// What is wrong with an amount of [status], if anything worth saying. An
  /// amount still to be typed is not.
  String? _amountProblem(AppLocalizations l10n, AmountStatus status, {required SendFee? fee}) {
    final fmt = ref.read(numberFormattingServiceProvider);
    String amount(BigInt value) => l10n.commonAmountBalance(fmt.formatBalance(value), AppConstants.tokenSymbol);

    return switch (status) {
      AmountStatus.valid || AmountStatus.zero => null,
      AmountStatus.negative => l10n.sendLogicInvalidAmount,
      AmountStatus.belowMinimum => l10n.sendLogicBelowMinimum(
        fmt.formatAmount(SendScreenLogic.minimumSendAmount),
        AppConstants.tokenSymbol,
      ),
      AmountStatus.insufficientBalance => l10n.desktopSendAmountTooMuch(amount(_maxSendable(fee))),
    };
  }

  // ------------------------------------------------------------- the steps

  void _openReview() {
    // Review is offered by the form as it was last drawn; the address may
    // have changed since.
    if (!_recipientAccepted) return;
    final feeState = ref.read(_feeProvider);
    final fee = feeState.fee;
    if (fee == null) throw StateError('The review was opened before the send had a fee.');
    // The review prices the exact send; a quote may still be waiting its turn.
    if (!_feeApplies(feeState)) _requestFee(_amount, immediate: true);
    _stepFocus.requestFocus();
    _pendingPaste = null;
    setState(() {
      _reviewedRecipient = _typedAddress;
      _openedWith = fee;
      _error = null;
      _step = _Step.review;
    });
  }

  void _backToForm() {
    if (_isSending) return;
    // Back where the typing left off, once the field is there again; a
    // locked amount cannot take the keyboard.
    (_isMax ? _addressFocus : _amountFocus).requestFocus();
    setState(() {
      _reviewedRecipient = null;
      _error = null;
      _step = _Step.form;
    });
  }

  Future<void> _send(SendReview review, List<SendReviewRow> rows) async {
    if (_isSending || review.confirmBlocked) return;
    setState(() {
      _isSending = true;
      _error = null;
    });

    final failed = ref.read(l10nProvider).sendReviewSubmitFailed;
    SendOutcome outcome;
    try {
      outcome = await _strategy.submit(
        ref,
        recipientAddress: _recipient,
        amount: review.amount,
        fee: review.fee,
        isPayMode: false,
        sendAll: _sendAll,
      );
    } catch (e, st) {
      quantusPrint('Send failed: $e\n$st');
      outcome = SendFailed(failed);
    }
    if (!mounted) return;

    switch (outcome) {
      case SendSubmitted(:final terminal, :final confirmation):
        setState(() {
          _isSending = false;
          _submitted = terminal;
          _submittedRows = rows;
          _confirmation = confirmation;
          _step = _Step.receipt;
        });
      case SendFailed(:final message):
        setState(() {
          _isSending = false;
          _error = message;
        });
      case SendNeedsProving(:final account, :final plan, :final amount, :final terminal):
        // The proving lives as long as something listens to it: from here
        // on the sheet does, and moves on once every proof is handed over.
        ref.listenManual(encryptedSendControllerProvider, (_, next) {
          if (next.phase == EncryptedSendPhase.succeeded && _step == _Step.proving) {
            setState(() => _step = _Step.receipt);
          }
        });
        setState(() {
          _isSending = false;
          _provingAmount = amount;
          _submitted = terminal;
          _submittedRows = rows;
          _step = _Step.proving;
        });
        unawaited(
          ref
              .read(encryptedSendControllerProvider.notifier)
              .start(account: account, plan: plan, amount: amount, recipientAddress: _recipient),
        );
      case SendNeedsHardwareSignature():
        setState(() {
          _isSending = false;
          _error = failed;
        });
        // Send is offered only on accounts whose key signs in the app.
        throw StateError('The desktop app cannot finish this send: $outcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    // A maximum send follows its fee, on whichever step the sheet is.
    ref.listen(_feeProvider, (_, next) {
      if (_isMax && _step != _Step.receipt && next.fee != null) _setAmount(_maxSendable(next.fee));
    });
    final title = _strategy.strings(l10n).flowTitle;
    final isReview = _step == _Step.review;
    // A send being proved cannot be left, only stopped.
    final isProving = _step == _Step.proving && _isUnderWay(ref.watch(encryptedSendControllerProvider));

    return PopScope(
      canPop: !_isSending && !isProving,
      child: SheetBackShortcut(
        onBack: isReview && !_isSending ? _backToForm : null,
        child: Focus(
          focusNode: _stepFocus,
          skipTraversal: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShellSheetHeader(
                title: isReview ? l10n.desktopSendReview : title,
                account: _account,
                parent: isReview ? (title: title, onBack: _backToForm) : null,
              ),
              ...switch (_step) {
                _Step.form => _form(l10n),
                _Step.review => _review(l10n),
                _Step.proving => _proving(l10n),
                _Step.receipt => _receipt(l10n),
              },
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- the form

  List<Widget> _form(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final balance = ref.watch(_strategy.spendableBalanceProvider);
    final feeState = ref.watch(_feeProvider);
    final fee = feeState.fee;
    final availability = ref.watch(approvalAvailabilityProvider);
    // What is still on its way back to the account, where a send can leave
    // some.
    final pendingProvider = _strategy.pendingBalanceProvider;
    final pending = pendingProvider == null ? null : ref.watch(pendingProvider).value;
    // Said beside the buttons where a send could not be approved.
    final approvalNote = switch (availability) {
      AsyncData(:final value) => approvalUnavailableNote(l10n, value),
      AsyncError(:final error) => l10n.desktopApprovalFailed('$error'),
      _ => null,
    };

    final amountStatus = SendScreenLogic.getAmountStatus(
      _amount,
      balance.value ?? BigInt.zero,
      _strategy.feeChargedToBalance(fee),
    );
    final signer = _signer;
    final affordabilityError = fee == null ? null : _strategy.affordabilityError(ref, fee, l10n);
    // A proposal's cost is its member's to pay, not the amount's fault: it
    // is said of that account, under the cost.
    final costProblem = affordabilityError == null || signer == null
        ? null
        : l10n.desktopProposeCostNotCovered(signer.name);
    // A balance that is not known is not a shortfall: Review is unavailable
    // without the amount being called too much.
    final amountProblem = _amountUnreadable
        ? l10n.sendInputAmountInvalidAmount
        : amountStatus == AmountStatus.insufficientBalance && !balance.hasValue
        ? null
        : _amountProblem(l10n, amountStatus, fee: fee) ?? (costProblem == null ? affordabilityError : null);
    final canReview =
        _recipientAccepted &&
        fee != null &&
        balance.hasValue &&
        !_strategy.extraBalancesLoading(ref) &&
        affordabilityError == null &&
        amountStatus == AmountStatus.valid &&
        availability.value == ApprovalAvailability.available;

    return [
      const SizedBox(height: 14),
      SendFieldLabel(
        label: l10n.sendTxSubmittedToLabel,
        actions: [
          ToolbarAction.symbol(
            key: SendSheet.pasteKey,
            symbol: CupertinoIcons.doc_on_clipboard,
            label: l10n.desktopImportPaste,
            onPressed: _paste,
          ),
        ],
      ),
      const SizedBox(height: 6),
      SendField(
        key: SendSheet.addressFieldKey,
        controller: _address,
        focusNode: _addressFocus,
        hint: l10n.desktopSendAddressHint,
        style: context.sendMono(colors.textWhite),
        error: _addressProblem(l10n),
        onSubmitted: (_) => _amountFocus.requestFocus(),
      ),
      if (_recipient.isEmpty && _recents.isNotEmpty) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: CapsText(l10n.sendSelectRecipientRecents, style: context.sendCaps()),
        ),
        // The list takes the height the window leaves and scrolls within it,
        // so the fields and the buttons under it stay in the sheet.
        Flexible(
          child: ListView(
            key: SendSheet.recentsKey,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final address in _recents)
                SendRecentRow(
                  key: SendSheet.recentKey(address),
                  address: address,
                  onPressed: () => _address.text = address,
                ),
            ],
          ),
        ),
      ] else if (_isChecking) ...[
        const SizedBox(height: 10),
        Text(l10n.sendRecipientChecking, style: context.sendBody()),
      ] else if (_recipientAccepted) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            CapsText(l10n.componentCheckphraseLabel, style: context.sendCaps()),
            const SizedBox(width: 12),
            Flexible(
              child: CheckphraseText(
                _recipient,
                style: context.sendMono(colors.semanticLilac),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 18),
      SendFieldLabel(label: l10n.sendReviewAmount),
      const SizedBox(height: 6),
      SendField(
        key: SendSheet.amountFieldKey,
        controller: _amountText,
        focusNode: _amountFocus,
        hint: '0',
        style: context.themeTextV3.amountRow,
        enabled: !_isMax,
        error: amountProblem,
        suffix: AppConstants.tokenSymbol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider))],
        onChanged: _onAmountChanged,
        onSubmitted: (_) {
          if (canReview) _openReview();
        },
      ),
      const SizedBox(height: 8),
      // What can be spent at the line's start and what the send costs at its
      // end; where they do not fit side by side, the cost goes under.
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _figure(l10n.desktopSendAvailable, switch (ref.watch(_strategy.displayBalanceProvider)) {
                AsyncValue(:final value?) => l10n.commonAmountBalance(
                  fmt.formatBalance(value),
                  AppConstants.tokenSymbol,
                ),
                AsyncError() => '—',
                _ => '…',
              }),
              if (pending != null && pending > BigInt.zero)
                _figure(
                  l10n.activityTxPending,
                  l10n.commonAmountBalance(fmt.formatBalance(pending), AppConstants.tokenSymbol),
                  color: colors.textMuted2,
                ),
            ],
          ),
          Row(mainAxisSize: MainAxisSize.min, children: _feeLine(l10n, fmt, feeState)),
        ],
      ),
      if (costProblem != null) ...[
        const SizedBox(height: 4),
        Text(
          costProblem,
          key: SendSheet.costProblemKey,
          textAlign: TextAlign.end,
          style: context.themeTextV3.caption.copyWith(color: colors.semanticEmber),
        ),
      ],
      const SizedBox(height: 12 - DesktopCheckbox.boxInset),
      // The box on the content's edge, under the start of the line above.
      Transform.translate(
        offset: const Offset(-DesktopCheckbox.boxInset, 0),
        child: DesktopCheckbox(
          key: SendSheet.maxKey,
          value: _isMax,
          label: signer == null ? l10n.desktopSendMaximum : l10n.desktopProposeMaximum,
          onChanged: balance.hasValue ? _setMax : null,
        ),
      ),
      if (_strategy.showPrivateSendNotice) ...[
        const SizedBox(height: 16 - DesktopCheckbox.boxInset),
        NoticeBox(
          key: SendSheet.privateNoticeKey,
          tone: colors.accentFlare,
          symbol: CupertinoIcons.lock_fill,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.privateSendTitle, style: context.themeTextV3.bodyEmphasis),
                const TextSpan(text: '   '),
                TextSpan(text: l10n.privateSendSubtitle),
              ],
            ),
            style: context.themeTextV3.body.copyWith(color: colors.textContent),
          ),
        ),
        const SizedBox(height: 20),
      ] else
        const SizedBox(height: 26 - DesktopCheckbox.boxInset),
      Row(
        children: [
          Expanded(
            child: approvalNote == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(approvalNote, style: context.sendBody()),
                  ),
          ),
          SheetButton(
            key: SendSheet.cancelKey,
            label: l10n.commonCancel,
            kind: SheetButtonKind.secondary,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: SendSheet.reviewKey,
            label: l10n.desktopSendReview,
            isDisabled: !canReview,
            onTap: _openReview,
          ),
        ],
      ),
    ];
  }

  /// A figure of the line under the amount, after what it is.
  Widget _figure(String label, String value, {Color? color}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: context.sendBody(color: color)),
      const SizedBox(width: 8),
      Text(value, style: context.sendBody(color: color)),
    ],
  );

  /// What the network takes, at the end of the line under the amount: an
  /// estimate until the fee priced exactly this send, and a way to ask again
  /// when it could not be had.
  List<Widget> _feeLine(AppLocalizations l10n, NumberFormattingService fmt, SendFeeState feeState) {
    final fee = feeState.fee;
    final signer = _signer;
    String cost(SendFee fee) => estimateLabel(
      l10n.commonAmountBalance(fmt.formatBalance(fee.displayFee, smartDecimals: 5), AppConstants.tokenSymbol),
      estimate: !_feeApplies(feeState),
    );
    final retry = ToolbarAction.symbol(
      key: SendSheet.retryFeeKey,
      symbol: CupertinoIcons.arrow_clockwise,
      label: l10n.homeActivityRetry,
      onPressed: () => _strategy.retryFee(ref, recipient: _pricedRecipient, amount: _amount),
    );

    return [
      if (fee == null && feeState.failed)
        Text(
          _strategy.strings(l10n).feeFetchFailedMessage,
          style: context.sendBody(color: context.colorsV3.semanticEmber),
        )
      else ...[
        Text(signer == null ? sendFeeLabel(_strategy, l10n) : l10n.desktopProposeCost, style: context.sendBody()),
        const SizedBox(width: 8),
        if (fee == null)
          const Loader(size: 12)
        else ...[
          Text(signer == null ? cost(fee) : l10n.desktopProposeCostPaidBy(cost(fee)), style: context.sendBody()),
          // The name takes what the cost leaves it, and is cut short there.
          if (signer != null) ...[
            const SizedBox(width: 8),
            Flexible(child: AccountLabel(account: signer, revealsAddress: true)),
          ],
        ],
      ],
      if (feeState.failed) ...[const SizedBox(width: 4), retry],
    ];
  }

  // ------------------------------------------------------------- the review

  List<Widget> _review(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final openedWith = _openedWith;
    if (openedWith == null) throw StateError('The review step has no fee to open with.');
    final review = SendReview.of(
      _strategy,
      feeState: ref.watch(_feeProvider),
      openedWith: openedWith,
      spendable: ref.watch(_strategy.spendableBalanceProvider).value,
      enteredAmount: _amount,
      sendAll: _sendAll,
    );
    final rows = _strategy.reviewRows(
      ref,
      recipientAddress: _recipient,
      amount: review.amount,
      fee: review.fee,
      feeIsEstimate: !review.feeApplies,
      sendAll: _sendAll,
    );
    final strings = _strategy.strings(l10n);
    // What the account that pays holds can move while the review stands: a
    // proposal's cost is its member's to pay, and is said of that account.
    final signer = _signer;
    final costProblem = _strategy.affordabilityError(ref, review.fee, l10n) == null || signer == null
        ? null
        : l10n.desktopProposeCostNotCovered(signer.name);
    // Beside the buttons: what stops the send, or why the last press sent
    // nothing.
    final problem =
        _amountProblem(l10n, review.amountStatus, fee: review.fee) ??
        costProblem ??
        (review.feeFailed ? strings.feeFetchFailedMessage : _error);

    return [
      const SizedBox(height: 26),
      CapsText(_signer == null ? strings.reviewHeroLabel : l10n.desktopProposeProposing, style: context.sendCaps()),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              // A max send's amount moves with its fee until that is exact.
              estimateLabel(
                fmt.formatBalance(review.amount, smartDecimals: AppConstants.decimals),
                estimate: _sendAll && !review.feeApplies,
              ),
              overflow: TextOverflow.ellipsis,
              style: text.displayBalance.copyWith(color: colors.textContent),
            ),
          ),
          const SizedBox(width: 8),
          Text(AppConstants.tokenSymbol, style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
        ],
      ),
      const SizedBox(height: 24),
      // The lines scroll where the window is too low for them all; what is
      // paid in all and the buttons stay under them in the sheet.
      Flexible(
        child: SingleChildScrollView(
          child: SendSummary(
            l10n: l10n,
            recipient: _recipient,
            from: _account,
            rows: rows,
            feeLabel: sendFeeLabel(_strategy, l10n),
            signer: _signer,
          ),
        ),
      ),
      SendTotal(rows: rows, label: _signer == null ? l10n.swapYouPay : l10n.desktopProposePays, signer: _signer),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: problem == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      problem,
                      key: identical(problem, costProblem) ? SendSheet.costProblemKey : null,
                      style: context.sendBody(color: colors.semanticEmber),
                    ),
                  ),
          ),
          if (review.feeFailed) ...[
            ToolbarAction.symbol(
              key: SendSheet.retryFeeKey,
              symbol: CupertinoIcons.arrow_clockwise,
              label: l10n.homeActivityRetry,
              onPressed: () => _strategy.retryFee(ref, recipient: _recipient, amount: _amount),
            ),
            const SizedBox(width: 10),
          ],
          SheetButton(
            key: SendSheet.backKey,
            label: l10n.commonBack,
            kind: SheetButtonKind.secondary,
            isDisabled: _isSending,
            onTap: _backToForm,
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: SendSheet.sendKey,
            label: _signer == null ? strings.flowTitle : l10n.desktopProposeSubmit,
            isLoading: _isSending,
            isDisabled: review.confirmBlocked || costProblem != null,
            onTap: () => _send(review, rows),
          ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------ the proving

  /// The send is being proved or handed over, or is about to be.
  static bool _isUnderWay(EncryptedSendState send) => send.isRunning || send.phase == EncryptedSendPhase.idle;

  List<Widget> _proving(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final send = ref.watch(encryptedSendControllerProvider);
    final amount = _provingAmount;
    if (amount == null) throw StateError('The proving step has no send to prove.');

    final isUnderWay = _isUnderWay(send);
    final isCanceling = send.phase == EncryptedSendPhase.canceling;
    final isCancelled = send.phase == EncryptedSendPhase.cancelled;
    final hasFailed = send.phase == EncryptedSendPhase.failed || send.phase == EncryptedSendPhase.planStale;
    final failure = send.phase == EncryptedSendPhase.planStale ? l10n.encryptedSendPlanStale : send.errorMessage;
    final steps = WormholeStepStates(
      stepProgress: send.stepProgress,
      currentStep: send.currentStep,
      done: false,
      cancelled: isCancelled,
      hasError: hasFailed,
    );
    String amountLabel(BigInt value) => l10n.commonAmountBalance(fmt.formatBalance(value), AppConstants.tokenSymbol);

    return [
      const SizedBox(height: 26),
      CapsText(
        hasFailed
            ? l10n.encryptedSendFailedTitle
            : isCancelled
            ? l10n.encryptedSendCancelledTitle
            : l10n.encryptedSendingLabel,
        style: context.sendCaps(
          color: hasFailed
              ? colors.semanticEmber
              : isCancelled
              ? colors.semanticSand
              : null,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              fmt.formatBalance(amount, smartDecimals: AppConstants.decimals),
              overflow: TextOverflow.ellipsis,
              style: text.displayBalance.copyWith(color: colors.textContent),
            ),
          ),
          const SizedBox(width: 8),
          Text(AppConstants.tokenSymbol, style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
        ],
      ),
      const SizedBox(height: 22),
      CapsText(l10n.sendTxSubmittedToLabel, style: context.sendCaps()),
      const SizedBox(height: 10),
      DesktopAddressCheckphrase(address: _recipient),
      const SizedBox(height: 26),
      for (final (step, name) in encryptedSendSteps(l10n)) _stepLine(l10n, send, steps, step, name),
      // What ended the send early. However long, it leaves the button under
      // it in the sheet.
      if (isCancelled || failure != null) ...[
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            child: isCancelled
                ? send.submittedRecipientToken > BigInt.zero
                      ? NoticeBox(
                          tone: colors.semanticSand,
                          child: Text(
                            l10n.encryptedSendCancelledPartial(amountLabel(send.submittedRecipientToken)),
                            style: text.body.copyWith(color: colors.textContent),
                          ),
                        )
                      : NoticeBox(
                          tone: colors.semanticSage,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.encryptedSendFundsSafeLabel,
                                style: text.bodyEmphasis.copyWith(color: colors.textContent),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.encryptedSendFundsSafeCaption(_account.name),
                                style: text.body.copyWith(color: colors.textContent),
                              ),
                            ],
                          ),
                        )
                : NoticeBox(
                    tone: colors.semanticEmber,
                    child: Text(failure!, style: text.body.copyWith(color: colors.textContent)),
                  ),
          ),
        ),
      ],
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: isUnderWay
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      isCanceling ? l10n.commonCanceling : l10n.encryptedSendProgressFooter,
                      style: context.sendBody(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (isUnderWay)
            SheetButton(
              key: SendSheet.stopKey,
              label: l10n.commonCancel,
              kind: SheetButtonKind.secondary,
              isDisabled: isCanceling,
              onTap: () => unawaited(ref.read(encryptedSendControllerProvider.notifier).cancel()),
            )
          else
            SheetButton(key: SendSheet.closeKey, label: l10n.commonClose, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    ];
  }

  /// One step of the proving as a line of the terminal: done, at work with how
  /// far it is, where the send stopped or failed, or still to come.
  ///
  /// The first step is at work from the press of Send, before the proving has
  /// said anything: the wallet is already checking its balance for it.
  Widget _stepLine(AppLocalizations l10n, EncryptedSendState send, WormholeStepStates steps, int step, String name) {
    final colors = context.colorsV3;
    final progress = send.stepProgress[step];
    final total = progress?.total;
    final hasNotReported = send.currentStep == 0 && send.stepProgress.isEmpty;
    final isBusy =
        steps.of(step) == StepRowState.active ||
        (_isUnderWay(send) && hasNotReported && step == encryptedSendSteps(l10n).first.$1);
    final (String? status, Color? color) = isBusy
        ? (progress != null && total != null ? '${progress.completed}/$total' : null, colors.accentFlare)
        : switch (steps.of(step)) {
            StepRowState.done => (l10n.desktopBootStatusOk, colors.semanticSage),
            StepRowState.ended => (l10n.desktopSendStatusFailed, colors.semanticEmber),
            StepRowState.active || StepRowState.pending =>
              steps.stoppedAt(step) ? (l10n.desktopSendStatusStopped, colors.semanticSand) : (null, null),
          };

    return TerminalLine(
      key: SendSheet.stepKey(step),
      name: name,
      status: status,
      statusColor: color,
      isBusy: isBusy,
      isDim: status == null && !isBusy,
    );
  }

  // ------------------------------------------------------------ the receipt

  /// The explorer's page of each transaction the send was. A transparent send
  /// is one; a private send is one for each batch of its inputs.
  List<String> _explorerPages(SendTerminalContent submitted) {
    // A send that was proved: the proving knows what it handed to the chain.
    if (_provingAmount != null) {
      return [for (final hash in ref.watch(encryptedSendControllerProvider).txHashes) wormholeExplorerUrl(hash)];
    }
    return [?submitted.explorerUrl];
  }

  ToolbarAction _viewInExplorer(AppLocalizations l10n, String page, {Key? key}) => ToolbarAction.symbol(
    key: key,
    symbol: CupertinoIcons.arrow_up_right_square,
    label: l10n.desktopViewInExplorer,
    onPressed: () => ref.read(openExternalUrlProvider)(Uri.parse(page)),
  );

  /// The line over the receipt: what became of the send, as far as known.
  Widget _receiptStatus(AppLocalizations l10n, SendConfirmation confirmation) {
    final colors = context.colorsV3;
    final (color, label) = switch (confirmation) {
      SendConfirmation.confirmed => (colors.semanticSage, l10n.desktopSendSubmitted),
      SendConfirmation.pending => (colors.textMuted, l10n.desktopProposeConfirming),
      SendConfirmation.unconfirmed => (colors.semanticEmber, l10n.desktopProposeNotConfirmed),
    };
    final style = context.sendCaps(color: color, spacing: 2.4);
    const markSize = 13.0;
    final mark = switch (confirmation) {
      SendConfirmation.confirmed => Icon(CupertinoIcons.checkmark_alt, size: markSize, color: color),
      // Waiting has a part that moves, unless the system asks for none.
      SendConfirmation.pending =>
        MediaQuery.disableAnimationsOf(context) ? null : TerminalSpinner(style: style.copyWith(letterSpacing: 0)),
      SendConfirmation.unconfirmed => Icon(CupertinoIcons.exclamationmark_circle, size: markSize, color: color),
    };

    // As high with one mark as with another, or with none: what is under it
    // stays where it is when the send's fate is learned.
    return SizedBox(
      height: markSize,
      child: Row(
        children: [
          if (mark != null) ...[mark, const SizedBox(width: 8)],
          CapsText(label, style: style),
        ],
      ),
    );
  }

  List<Widget> _receipt(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final submitted = _submitted;
    if (submitted == null) throw StateError('The receipt step has no submitted send.');
    // A receipt that waits for nothing says what holds from the broadcast on.
    final waitsFor = _confirmation;
    final confirmation = waitsFor == null ? SendConfirmation.confirmed : ref.watch(waitsFor);
    final isConfirmed = confirmation == SendConfirmation.confirmed;
    final pages = _explorerPages(submitted);
    // Only macOS has a share picker to hand the pages to.
    final canShare = pages.isNotEmpty && defaultTargetPlatform == TargetPlatform.macOS;
    // A proposal's receipt says what was proposed: the amount, as its
    // terminal content words it.
    final proposed = _signer == null
        ? null
        : submitted.amountText ?? (throw StateError('A submitted proposal has no amount to name.'));

    return [
      const SizedBox(height: 26),
      _receiptStatus(l10n, confirmation),
      const SizedBox(height: 14),
      Text(
        proposed == null
            ? submitted.headline
            : isConfirmed
            ? l10n.desktopProposeProposed(proposed)
            : l10n.desktopProposeProposingAmount(proposed),
        style: context.themeTextV3.titleHero.copyWith(
          fontSize: 26,
          height: 1.05,
          letterSpacing: -0.65,
          color: colors.textWhite,
        ),
      ),
      const SizedBox(height: 10),
      // Until its transaction has created it, a proposal is only on its way
      // to being one: the wait is said in place of what follows a proposal,
      // and so is the wallet having stopped waiting.
      switch (confirmation) {
        SendConfirmation.confirmed => Text(submitted.subline, style: context.sendBody()),
        SendConfirmation.pending => Text(l10n.desktopProposeWaiting, style: context.sendBody()),
        SendConfirmation.unconfirmed => Text(
          l10n.multisigProposeTimeoutToast,
          style: context.sendBody(color: colors.semanticEmber),
        ),
      },
      const SizedBox(height: 24),
      Flexible(
        child: SingleChildScrollView(
          child: SendSummary(
            l10n: l10n,
            recipient: submitted.recipientAddress,
            from: _account,
            rows: _submittedRows,
            feeLabel: sendFeeLabel(_strategy, l10n),
            signer: _signer,
            // Proposing is the proposer's own approval, the first, once
            // there is a proposal to have approved.
            approvals: _signer == null
                ? null
                : isConfirmed
                ? 1
                : 0,
          ),
        ),
      ),
      SendTotal(
        rows: _submittedRows,
        label: _signer == null
            ? l10n.desktopSendYouPaid
            : isConfirmed
            ? l10n.desktopProposePaid
            : l10n.desktopProposePays,
        signer: _signer,
      ),
      // A send that took several transactions names each, with its own page.
      // However many, they leave the buttons under them in the sheet.
      if (pages.length > 1) ...[
        const MenuDivider(),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              for (final (index, page) in pages.indexed)
                Row(
                  key: SendSheet.transactionKey(index),
                  children: [
                    Expanded(
                      child: Text(l10n.desktopSendTransactionOf(index + 1, pages.length), style: context.sendBody()),
                    ),
                    ToolbarActionRow(edge: ToolbarActionEdge.trailing, children: [_viewInExplorer(l10n, page)]),
                  ],
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      Row(
        children: [
          ToolbarActionRow(
            edge: ToolbarActionEdge.leading,
            children: [
              if (pages.length == 1) _viewInExplorer(l10n, pages.single, key: SendSheet.explorerKey),
              if (canShare)
                Builder(
                  builder: (button) => ToolbarAction.symbol(
                    key: SendSheet.shareKey,
                    symbol: CupertinoIcons.square_arrow_up,
                    label: l10n.componentShare,
                    onPressed: () => ref.read(shareTextProvider)(pages.join('\n'), origin: button.sharePositionRect()),
                  ),
                ),
            ],
          ),
          const Spacer(),
          SheetButton(key: SendSheet.doneKey, label: submitted.doneLabel, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    ];
  }
}
