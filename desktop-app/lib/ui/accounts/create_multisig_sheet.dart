import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/keystone/keystone_signing_view.dart';
import 'package:quantus_desktop_wallet/ui/send/send_form_parts.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/managed_multisigs.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/services/multisig_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/utils/multisig_form.dart';

enum _Step { form, review, signing }

/// Creates a multisig: a form of its name, signers and approvals, then a
/// review of its address and what it costs. The active account creates it,
/// pays and is its first signer ([multisigCreatorProvider]). It cannot be
/// closed while the creation is being submitted.
class CreateMultisigSheet extends ConsumerStatefulWidget {
  const CreateMultisigSheet({super.key});

  static const nameFieldKey = Key('create-multisig-name');
  static const signerFieldKey = Key('create-multisig-signer');
  static const addSignerKey = Key('create-multisig-add-signer');
  static const approvalsKey = Key('create-multisig-approvals');
  static const tryAgainKey = Key('create-multisig-try-again');
  static const reviewKey = Key('create-multisig-review');
  static const backKey = Key('create-multisig-back');
  static const createKey = Key('create-multisig-create');

  static Key removeSignerKey(String address) => ValueKey('create-multisig-remove-$address');

  @override
  ConsumerState<CreateMultisigSheet> createState() => _CreateMultisigSheetState();
}

class _CreateMultisigSheetState extends ConsumerState<CreateMultisigSheet> {
  late final Account _creator;
  late final TextEditingController _name;
  final _signerField = TextEditingController();
  final _nameFocus = FocusNode();
  final _signerFocus = FocusNode();
  final _stepFocus = FocusNode(skipTraversal: true);

  _Step _step = _Step.form;
  List<String> _others = const [];
  late int _threshold;
  String? _signerError;

  /// The new multisig's address and nonce, for the signers and approvals as
  /// they are; null until worked out.
  MultisigCreationParams? _resolved;
  bool _isPreviewing = false;
  String? _previewError;

  /// Counts the previews asked for: an answer for an older one is dropped.
  int _previewRequest = 0;

  /// What the last check found, for the review to show.
  MultisigCreationPreflight? _preflight;
  bool _isChecking = false;
  bool _isSubmitting = false;

  /// Why the last press went no further.
  String? _problem;

  /// The creator's cold wallet signing the creation, on the signing step.
  KeystoneSigningSession? _signing;

  List<String> get _signers => multisigSigners(_creator.accountId, _others);

  @override
  void initState() {
    super.initState();
    final creator = ref.read(multisigCreatorProvider);
    if (creator == null) throw StateError('Create Multisig was opened on an account that cannot sign here.');
    _creator = creator;
    final creating = ref.read(pendingMultisigCreationsProvider.notifier).records.map((record) => record.draft);
    final name = nextDefaultMultisigName(ref.read(l10nProvider), [
      ...ref.read(multisigAccountsProvider).requireValue,
      ...creating,
    ]);
    _name = TextEditingController(text: name)..selection = TextSelection(baseOffset: 0, extentOffset: name.length);
    _threshold = MultisigService.defaultThreshold(_signers.length);
    // After the first frame: the sheet's own focus takes the autofocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _signerField.dispose();
    _nameFocus.dispose();
    _signerFocus.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  Set<String> _reserved() => reservedMultisigAddresses(
    saved: ref.read(multisigAccountsProvider).value ?? const [],
    creating: ref.read(pendingMultisigCreationsProvider),
  );

  // ------------------------------------------------------------ the signers

  void _addSigner() {
    final l10n = ref.read(l10nProvider);
    final address = _signerField.text.trim();
    if (address.isEmpty) return;
    final problem = newSignerProblem(
      address,
      isValidAddress: ref.read(substrateServiceProvider).isValidSS58Address,
      signers: _signers,
      reserved: _reserved(),
    );
    if (problem != null) {
      setState(
        () => _signerError = switch (problem) {
          SignerProblem.invalid => l10n.multisigCreateInvalidSigner,
          SignerProblem.duplicate => l10n.multisigCreateDuplicateSigner,
          SignerProblem.isMultisig => l10n.multisigCreateSignerIsMultisig,
        },
      );
      return;
    }
    _signerField.clear();
    _signerFocus.requestFocus();
    _setSigners([..._others, address]);
  }

  void _setSigners(List<String> others) {
    setState(() {
      _others = others;
      _signerError = null;
      _problem = null;
      _threshold = MultisigService.defaultThreshold(_signers.length);
    });
    unawaited(_refreshPreview());
  }

  void _setThreshold(int threshold) {
    if (threshold == _threshold) return;
    setState(() {
      _threshold = threshold;
      _problem = null;
    });
    unawaited(_refreshPreview());
  }

  Future<void> _refreshPreview() async {
    final request = ++_previewRequest;
    if (_signers.length < minMultisigSigners) {
      setState(() {
        _resolved = null;
        _isPreviewing = false;
        _previewError = null;
      });
      return;
    }
    setState(() {
      _resolved = null;
      _isPreviewing = true;
      _previewError = null;
    });
    final l10n = ref.read(l10nProvider);
    try {
      final resolved = await ref
          .read(multisigServiceProvider)
          .resolveMultisigCreationParams(signers: _signers, threshold: _threshold, reservedAddresses: _reserved());
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _resolved = resolved;
        _isPreviewing = false;
      });
    } catch (e) {
      quantusPrint('Working out the new multisig\'s address failed: $e');
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _isPreviewing = false;
        _previewError = l10n.desktopCreateMultisigPreviewFailed('$e');
      });
    }
  }

  // -------------------------------------------------------------- the steps

  /// Checks the chain for the multisig as it stands: that its address is
  /// free, what it costs, and that the payer can afford it. Null when it
  /// cannot go ahead, with why said.
  Future<MultisigCreationPreflight?> _check(MultisigCreationParams resolved) async {
    final l10n = ref.read(l10nProvider);
    try {
      return await ref
          .read(multisigSubmissionServiceProvider)
          .preflightMultisigCreation(
            name: _name.text.trim(),
            signers: _signers,
            threshold: _threshold,
            creator: _creator,
            nonce: resolved.nonce,
          );
    } on MultisigAlreadyExistsException {
      _stop(l10n.multisigCreateAlreadyExists, toForm: true);
    } on MultisigInsufficientBalanceException {
      _stop(l10n.desktopCreateMultisigCantAfford(_creator.name), toForm: true);
    } catch (e) {
      quantusPrint('Checking the new multisig failed: $e');
      _stop(l10n.desktopCreateMultisigFailed('$e'));
    }
    return null;
  }

  void _stop(String problem, {bool toForm = false}) {
    if (!mounted) return;
    if (toForm) _signerFocus.requestFocus();
    setState(() {
      _isChecking = false;
      _isSubmitting = false;
      _problem = problem;
      if (toForm) _step = _Step.form;
    });
  }

  Future<void> _openReview() async {
    final resolved = _resolved;
    if (resolved == null || _isChecking) return;
    final request = _previewRequest;
    setState(() {
      _isChecking = true;
      _problem = null;
    });
    final preflight = await _check(resolved);
    if (!mounted || preflight == null) return;
    // The form changed while it was being checked: what was checked is not
    // what would be reviewed.
    if (request != _previewRequest || _name.text.trim() != preflight.draft.name) {
      setState(() => _isChecking = false);
      return;
    }
    _stepFocus.requestFocus();
    setState(() {
      _isChecking = false;
      _preflight = preflight;
      _step = _Step.review;
    });
  }

  void _backFromSigning() {
    _stepFocus.requestFocus();
    setState(() {
      _signing = null;
      _step = _Step.review;
    });
  }

  void _backToForm() {
    if (_isSubmitting) return;
    _signerFocus.requestFocus();
    setState(() {
      _problem = null;
      _step = _Step.form;
    });
  }

  /// Checks the chain again, as the review may have stood a while and a
  /// submission that seemed to fail may have landed, asks for approval, and
  /// submits.
  Future<void> _create() async {
    final resolved = _resolved;
    if (resolved == null || _isSubmitting) return;
    final l10n = ref.read(l10nProvider);
    final submission = ref.read(multisigSubmissionServiceProvider);
    setState(() {
      _isSubmitting = true;
      _problem = null;
    });

    final preflight = await _check(resolved);
    if (!mounted || preflight == null) return;
    setState(() => _preflight = preflight);

    // A cold wallet approves on the cold wallet: the signing steps follow.
    if (_creator.signsWithHardware) {
      _stepFocus.requestFocus();
      setState(() {
        _isSubmitting = false;
        _signing = submission.creationSigningSession(preflight: preflight, creator: _creator);
        _step = _Step.signing;
      });
      return;
    }

    final refusal = await askForApproval(
      ref.read(userApprovalProvider),
      l10n,
      reason: l10n.multisigCreateAuthReason,
      declined: l10n.desktopCreateMultisigDeclined,
    );
    if (!mounted) return;
    if (refusal != null) return _stop(refusal);

    try {
      await submission.startMultisigCreation(preflight: preflight, creator: _creator);
    } catch (e) {
      quantusPrint('Creating the multisig failed: $e');
      return _stop(l10n.desktopCreateMultisigFailed('$e'));
    }
    if (mounted) Navigator.of(context).pop();
  }

  // --------------------------------------------------------------- drawing

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final isReview = _step == _Step.review;

    return PopScope(
      canPop: !_isSubmitting,
      child: SheetBackShortcut(
        onBack: isReview && !_isSubmitting ? _backToForm : null,
        child: Focus(
          focusNode: _stepFocus,
          skipTraversal: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The signing has its own headers: it has steps of its own.
              if (_step != _Step.signing) ...[
                ShellSheetHeader(
                  title: isReview ? l10n.desktopSendReview : l10n.multisigAddTitle,
                  parent: isReview ? (title: l10n.multisigAddTitle, onBack: _backToForm) : null,
                ),
                const SizedBox(height: 14),
              ],
              ...switch (_step) {
                _Step.form => _form(l10n),
                _Step.review => _review(l10n),
                _Step.signing => [
                  KeystoneSigningView(
                    session: _signing ?? (throw StateError('The signing step has no signing.')),
                    account: _creator,
                    parentTitle: l10n.multisigAddTitle,
                    onLeave: _backFromSigning,
                    onSubmitting: (_) {},
                    onSigned: (_) => Navigator.of(context).pop(),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  /// Whether approval can be asked for, and what to say where it cannot. A
  /// cold wallet's creation is approved on the cold wallet.
  ({bool isAvailable, String? note}) _approval(AppLocalizations l10n) {
    if (_creator.signsWithHardware) return (isAvailable: true, note: null);
    final availability = ref.watch(approvalAvailabilityProvider);
    return (
      isAvailable: availability.value == ApprovalAvailability.available,
      note: switch (availability) {
        AsyncData(:final value) => approvalUnavailableNote(l10n, value),
        AsyncError(:final error) => l10n.desktopApprovalFailed('$error'),
        _ => null,
      },
    );
  }

  List<Widget> _form(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final approval = _approval(l10n);
    final signerCount = _signers.length;
    final canReview =
        approval.isAvailable &&
        canCreateMultisig(
          name: _name.text,
          signers: _signers,
          hasPayer: true,
          nonce: _resolved?.nonce,
          isPreviewing: _isPreviewing,
          isSubmitting: _isChecking,
        );
    final problem = _problem ?? _previewError;

    return [
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormRow(
                label: l10n.desktopAccountInfoName,
                labelTop: _FormRow.besideField,
                child: SendField(
                  key: CreateMultisigSheet.nameFieldKey,
                  controller: _name,
                  focusNode: _nameFocus,
                  hint: l10n.desktopAccountInfoName,
                  style: text.body.copyWith(color: colors.textContent),
                  onChanged: (_) => setState(() => _problem = null),
                  onSubmitted: (_) => _signerFocus.requestFocus(),
                ),
              ),
              _FormRow(
                label: l10n.desktopCreateMultisigSigners,
                labelTop: _FormRow.besideBadge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _YouSigner(account: _creator, youLabel: l10n.multisigYouLabel),
                    for (final address in _others)
                      _OtherSigner(
                        key: ValueKey(address),
                        address: address,
                        remove: ToolbarActionRow(
                          edge: ToolbarActionEdge.trailing,
                          spacing: 0,
                          children: [
                            ToolbarAction.symbol(
                              key: CreateMultisigSheet.removeSignerKey(address),
                              symbol: CupertinoIcons.xmark,
                              label: l10n.desktopCreateMultisigRemoveSigner,
                              iconOnly: true,
                              onPressed: () => _setSigners(_others.where((other) => other != address).toList()),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SendField(
                            key: CreateMultisigSheet.signerFieldKey,
                            controller: _signerField,
                            focusNode: _signerFocus,
                            hint: l10n.multisigCreateAddSignerHint,
                            style: context.sendMono(colors.textWhite),
                            error: _signerError,
                            onChanged: (_) => setState(() => _signerError = null),
                            onSubmitted: (_) => _addSigner(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: (SendField.height - SheetButton.height) / 2),
                          child: SheetButton(
                            key: CreateMultisigSheet.addSignerKey,
                            label: l10n.multisigCreateAddSignerButton,
                            kind: SheetButtonKind.secondary,
                            isDisabled: _signerField.text.trim().isEmpty,
                            onTap: _addSigner,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _FormRow(
                label: l10n.desktopCreateMultisigApprovalsNeeded,
                labelTop: _FormRow.besidePopUp,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PopUpButton<int>(
                    key: CreateMultisigSheet.approvalsKey,
                    semanticLabel: l10n.desktopCreateMultisigApprovalsNeeded,
                    items: [
                      for (var count = 1; count <= signerCount; count++)
                        PopUpItem(count, l10n.multisigCreateThresholdValue(count, signerCount)),
                    ],
                    value: _threshold,
                    onSelected: _setThreshold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _FootNote(problem: problem, note: approval.note),
          ),
          if (_previewError != null) ...[
            SheetButton(
              key: CreateMultisigSheet.tryAgainKey,
              label: l10n.commonTryAgain,
              kind: SheetButtonKind.secondary,
              onTap: () => unawaited(_refreshPreview()),
            ),
            const SizedBox(width: 10),
          ],
          SheetButton(
            label: l10n.commonCancel,
            kind: SheetButtonKind.secondary,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: CreateMultisigSheet.reviewKey,
            label: l10n.desktopSendReview,
            isDisabled: !canReview,
            isLoading: _isPreviewing || _isChecking,
            onTap: () => unawaited(_openReview()),
          ),
        ],
      ),
    ];
  }

  List<Widget> _review(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final preflight = _preflight;
    if (preflight == null) throw StateError('The review was opened with nothing checked.');
    final approval = _approval(l10n);
    final draft = preflight.draft;
    final cost = MultisigCreationDraftFields.fromDraft(draft, networkFee: preflight.networkFee);
    String amount(BigInt value) =>
        l10n.commonAmountBalance(fmt.formatBalance(value, smartDecimals: 5), AppConstants.tokenSymbol);

    return [
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormRow(label: l10n.desktopAccountInfoName, child: _Value(draft.name, isStrong: true)),
              _FormRow(
                label: l10n.desktopCreateMultisigAddress,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DesktopAddressCheckphrase(address: draft.accountId, isCompact: true),
                ),
              ),
              _FormRow(
                label: l10n.desktopCreateMultisigApprovals,
                child: _Value(
                  l10n.desktopCreateMultisigApprovalsValue(draft.threshold, draft.signers.length),
                  isStrong: true,
                ),
              ),
              _FormRow(
                label: l10n.desktopCreateMultisigSigners,
                labelTop: _FormRow.besideBadge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _YouSigner(account: _creator, youLabel: l10n.multisigYouLabel),
                    for (final address in _others) _OtherSigner(address: address),
                  ],
                ),
              ),
              _FormRow(
                label: l10n.desktopCreateMultisigPaidBy,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AccountLabel(
                      account: _creator,
                      style: text.body.copyWith(color: colors.textContent),
                    ),
                  ),
                ),
              ),
              _FormRow(label: l10n.desktopCreateMultisigCreationFee, child: _Value(amount(cost.palletFee))),
              _FormRow(label: l10n.swapReviewNetworkFee, child: _Value(amount(cost.networkFee))),
              _FormRow(label: l10n.swapYouPay, child: _Value(amount(cost.totalCost), isStrong: true)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _FootNote(problem: _problem, note: approval.note),
          ),
          SheetButton(
            key: CreateMultisigSheet.backKey,
            label: l10n.commonBack,
            kind: SheetButtonKind.secondary,
            isDisabled: _isSubmitting,
            onTap: _backToForm,
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: CreateMultisigSheet.createKey,
            label: l10n.multisigAddTitle,
            isDisabled: !approval.isAvailable,
            isLoading: _isSubmitting,
            onTap: () => unawaited(_create()),
          ),
        ],
      ),
    ];
  }
}

/// A line of the sheet: what it is on the left, what it holds on the right.
class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.child, this.labelTop = _besideText});

  final String label;
  final Widget child;

  /// How far down the label sits, level with the first line of [child].
  final double labelTop;

  static const double _labelWidth = 128;
  static const double _besideText = 7;
  static const double besideField = 10;
  static const double besideBadge = 9;
  static const double besidePopUp = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: labelTop),
              child: Text(label, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A value of the review, level with its label.
class _Value extends StatelessWidget {
  const _Value(this.value, {this.isStrong = false});

  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        value,
        style: (isStrong ? text.bodyEmphasis : text.body).copyWith(
          color: isStrong ? colors.textContent : colors.textMuted,
        ),
      ),
    );
  }
}

/// The signer who creates the multisig: by badge and name, then the whole
/// address over its checkphrase.
class _YouSigner extends StatelessWidget {
  const _YouSigner({required this.account, required this.youLabel});

  final Account account;
  final String youLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: AccountLabel(
                  account: account,
                  style: context.themeTextV3.bodyEmphasis.copyWith(color: context.colorsV3.textContent),
                ),
              ),
              const SizedBox(width: 8),
              QuantusBadge(label: youLabel),
            ],
          ),
          const SizedBox(height: 4),
          DesktopAddressCheckphrase(address: account.accountId, isCompact: true),
        ],
      ),
    );
  }
}

/// Another signer: the whole address over its checkphrase, with a way to
/// [remove] it on the form.
class _OtherSigner extends StatelessWidget {
  const _OtherSigner({super.key, required this.address, this.remove});

  final String address;
  final Widget? remove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: DesktopAddressCheckphrase(address: address, isCompact: true)),
          ?remove,
        ],
      ),
    );
  }
}

/// Beside the buttons: why the last press went no further, in ember, or
/// else what stops approval being asked for.
class _FootNote extends StatelessWidget {
  const _FootNote({required this.problem, required this.note});

  final String? problem;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final message = problem ?? note;
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Semantics(
        liveRegion: true,
        child: Text(message, style: context.sendBody(color: problem == null ? null : context.colorsV3.semanticEmber)),
      ),
    );
  }
}
