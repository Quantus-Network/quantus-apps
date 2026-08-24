import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
import 'package:resonance_network_wallet/v2/components/multisig_threshold_slider.dart';
import 'package:resonance_network_wallet/v2/components/name_field.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/multisig_submission_service.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';

class AddMultisigScreen extends ConsumerStatefulWidget {
  const AddMultisigScreen({super.key});

  @override
  ConsumerState<AddMultisigScreen> createState() => _AddMultisigScreenState();
}

class _AddMultisigScreenState extends ConsumerState<AddMultisigScreen> {
  final _accountName = TextEditingController();
  final _signerAddressController = TextEditingController();
  final _checksumService = HumanReadableChecksumService();

  List<String> _additionalSigners = [];
  late int _threshold;
  bool _isLoading = false;
  bool _isPredictingAddress = false;
  String? _predictedAddress;
  BigInt? _resolvedNonce;
  String? _signerFieldError;
  int _predictSeq = 0;

  Account? _creator;
  String? _creatorChecksum;

  @override
  void initState() {
    super.initState();
    final multisigCount = ref.read(multisigAccountsProvider).value?.length ?? 0;
    final l10n = ref.read(l10nProvider);
    _accountName.text = l10n.multisigCreateDefaultName(multisigCount + 1);
    _accountName.addListener(() => setState(() {}));
    _signerAddressController.addListener(_onSignerFieldChanged);

    _creator = _resolveCreatorAccount();
    if (_creator != null) {
      _loadCreatorChecksum(_creator!.accountId);
    }
    _threshold = MultisigService.defaultThreshold(_allSigners.length);
  }

  @override
  void dispose() {
    _accountName.dispose();
    _signerAddressController.removeListener(_onSignerFieldChanged);
    _signerAddressController.dispose();
    super.dispose();
  }

  Account? _resolveCreatorAccount() {
    final active = ref.read(activeAccountProvider).value;
    if (active is RegularAccount) return active.account;
    final accounts = ref.read(accountsProvider).value ?? [];
    return accounts.isNotEmpty ? accounts.first : null;
  }

  Future<void> _loadCreatorChecksum(String accountId) async {
    final checksum = await _checksumService.getHumanReadableName(accountId);
    if (mounted) setState(() => _creatorChecksum = checksum);
  }

  List<String> get _allSigners {
    final creatorId = _creator?.accountId;
    if (creatorId == null) return List<String>.from(_additionalSigners);
    return [creatorId, ..._additionalSigners];
  }

  bool get _hasMinimumSigners => _allSigners.length >= 2;

  bool get _isDisabled =>
      _accountName.text.trim().isEmpty ||
      !_hasMinimumSigners ||
      _creator == null ||
      _isLoading ||
      (_hasMinimumSigners && (_isPredictingAddress || _resolvedNonce == null));

  void _onSignerFieldChanged() {
    setState(() {
      if (_signerFieldError != null) {
        _signerFieldError = null;
      }
    });
  }

  void _addSigner() {
    final l10n = ref.read(l10nProvider);
    final substrate = ref.read(substrateServiceProvider);
    final address = _signerAddressController.text.trim();

    if (!substrate.isValidSS58Address(address)) {
      setState(() => _signerFieldError = l10n.multisigCreateInvalidSigner);
      return;
    }
    if (address == _creator?.accountId || _additionalSigners.contains(address)) {
      setState(() => _signerFieldError = l10n.multisigCreateDuplicateSigner);
      return;
    }

    setState(() {
      _additionalSigners = [..._additionalSigners, address];
      _signerAddressController.clear();
      _signerFieldError = null;
      _threshold = MultisigService.defaultThreshold(_allSigners.length);
    });
    _refreshPredictedAddress();
  }

  void _removeSigner(String address) {
    setState(() {
      _additionalSigners = _additionalSigners.where((s) => s != address).toList();
      _threshold = MultisigService.defaultThreshold(_allSigners.length);
      if (_allSigners.length < 2) {
        _predictedAddress = null;
        _resolvedNonce = null;
      }
    });
    _refreshPredictedAddress();
  }

  void _onThresholdChanged(int value) {
    setState(() => _threshold = value);
    _refreshPredictedAddress();
  }

  Set<String> _reservedAddresses() {
    final saved = ref.read(multisigAccountsProvider).value?.map((a) => a.accountId) ?? const [];
    final pending = ref.read(pendingMultisigCreationsProvider).map((e) => e.multisigAddress);
    return {...saved, ...pending};
  }

  Future<void> _refreshPredictedAddress() async {
    if (!_hasMinimumSigners) {
      _predictSeq++;
      setState(() {
        _predictedAddress = null;
        _resolvedNonce = null;
        _isPredictingAddress = false;
      });
      return;
    }

    final seq = ++_predictSeq;
    setState(() => _isPredictingAddress = true);
    try {
      final resolved = await ref
          .read(multisigServiceProvider)
          .resolveMultisigCreationParams(
            signers: _allSigners,
            threshold: _threshold,
            reservedAddresses: _reservedAddresses(),
          );
      if (!mounted || seq != _predictSeq) return;
      setState(() {
        _predictedAddress = resolved.address;
        _resolvedNonce = resolved.nonce;
        _isPredictingAddress = false;
      });
    } on MultisigNonceExhaustedException {
      quantusPrint('[AddMultisigScreen] refreshPredictedAddress: MultisigNonceExhaustedException');

      if (!mounted || seq != _predictSeq) return;
      setState(() {
        _predictedAddress = null;
        _resolvedNonce = null;
        _isPredictingAddress = false;
      });
    } catch (e) {
      quantusPrint('[AddMultisigScreen] refreshPredictedAddress: unknown error: $e');

      if (!mounted || seq != _predictSeq) return;
      setState(() {
        _predictedAddress = null;
        _resolvedNonce = null;
        _isPredictingAddress = false;
      });
    }
  }

  Future<void> _createMultisig() async {
    final creator = _creator;
    final nonce = _resolvedNonce;
    if (creator == null || !_hasMinimumSigners || nonce == null) return;

    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    final submissionService = ref.read(multisigSubmissionServiceProvider);

    try {
      await submissionService.preflightMultisigCreation(
        signers: _allSigners,
        threshold: _threshold,
        creator: creator,
        nonce: nonce,
      );
    } on MultisigAlreadyExistsException {
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateAlreadyExists);
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    } on MultisigInsufficientBalanceException {
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateInsufficientBalance);
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    } catch (e) {
      quantusPrint('[AddMultisigScreen] preflight error: $e');

      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateErrorCouldNotCreate);
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigCreateAuthReason);
    if (!authed) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await submissionService.startMultisigCreation(
        name: _accountName.text.trim(),
        signers: _allSigners,
        threshold: _threshold,
        creator: creator,
        nonce: nonce,
      );

      if (!mounted) return;
      returnToAccountsScreen(context, ref, highlightAccountId: _predictedAddress!);
    } on MultisigAlreadyExistsException {
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateAlreadyExists);
      }
    } on MultisigInsufficientBalanceException {
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateInsufficientBalance);
      }
    } catch (e) {
      quantusPrint('[AddMultisigScreen] createMultisig error: $e');
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateErrorCouldNotCreate);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final pendingCreations = ref.watch(pendingMultisigCreationsProvider);
    final isCreatingInFlight =
        _predictedAddress != null && pendingCreations.any((e) => e.multisigAddress == _predictedAddress);
    final displayThreshold = _allSigners.isEmpty ? 1 : _threshold.clamp(1, _allSigners.length);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigAddTitle),
      mainContent: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NameField(controller: _accountName, subtitle: l10n.multisigCreateSubtitle),
            const SizedBox(height: 28),
            _SignersSection(
              l10n: l10n,
              creatorAccountId: _creator?.accountId,
              creatorChecksum: _creatorChecksum,
              additionalSigners: _additionalSigners,
              signerAddressController: _signerAddressController,
              signerFieldError: _signerFieldError,
              onAddSigner: _addSigner,
              onRemoveSigner: _removeSigner,
            ),
            const SizedBox(height: 28),
            MultisigThresholdSlider(
              threshold: displayThreshold,
              signerCount: _allSigners.length,
              label: l10n.multisigCreateThresholdLabel,
              valueLabel: l10n.multisigCreateThresholdValue(displayThreshold, _allSigners.length),
              onChanged: _onThresholdChanged,
            ),
            const SizedBox(height: 28),
            _PredictedAddressSection(l10n: l10n, isLoading: _isPredictingAddress, address: _predictedAddress),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: isCreatingInFlight ? l10n.multisigCreateCreatingButton : l10n.multisigCreateButton,
          onTap: _createMultisig,
          isLoading: _isLoading || isCreatingInFlight,
          isDisabled: _isDisabled || isCreatingInFlight,
        ),
      ),
    );
  }
}

class _SignersSection extends StatelessWidget {
  const _SignersSection({
    required this.l10n,
    required this.creatorAccountId,
    required this.creatorChecksum,
    required this.additionalSigners,
    required this.signerAddressController,
    required this.signerFieldError,
    required this.onAddSigner,
    required this.onRemoveSigner,
  });

  final AppLocalizations l10n;
  final String? creatorAccountId;
  final String? creatorChecksum;
  final List<String> additionalSigners;
  final TextEditingController signerAddressController;
  final String? signerFieldError;
  final VoidCallback onAddSigner;
  final ValueChanged<String> onRemoveSigner;

  bool get _canAddSigner {
    final address = signerAddressController.text.trim();
    return address.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigCreateSignersLabel, style: text.labelData.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          Text(l10n.multisigCreateSignersSubtitle, style: text.caption.copyWith(color: colors.textMuted)),
          const SizedBox(height: 16),
          if (creatorAccountId != null)
            MultisigSignerListTile(
              accountId: creatorAccountId!,
              checksum: creatorChecksum,
              isYou: true,
              youLabel: l10n.multisigYouLabel,
            ),
          ...additionalSigners.map(
            (address) => MultisigSignerListTile(accountId: address, onRemove: () => onRemoveSigner(address)),
          ),
          const SizedBox(height: 16),
          QuantusTextField(
            controller: signerAddressController,
            hint: l10n.multisigCreateAddSignerHint,
            error: signerFieldError,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAddSigner(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: QuantusButton.simple(
              label: l10n.multisigCreateAddSignerButton,
              variant: ButtonVariant.secondary,
              isDisabled: !_canAddSigner,
              onTap: onAddSigner,
              width: null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictedAddressSection extends ConsumerStatefulWidget {
  const _PredictedAddressSection({required this.l10n, required this.isLoading, required this.address});

  final AppLocalizations l10n;
  final bool isLoading;
  final String? address;

  @override
  ConsumerState<_PredictedAddressSection> createState() => _PredictedAddressSectionState();
}

class _PredictedAddressSectionState extends ConsumerState<_PredictedAddressSection> {
  String? _checksum;
  String? _prevAddress;

  Future<void> _loadChecksum() async {
    final checksumService = ref.read(humanReadableChecksumServiceProvider);

    final hasAddress = widget.address != null;
    final isNewAddress = widget.address != _prevAddress;

    if (hasAddress && isNewAddress) {
      final name = await checksumService.getHumanReadableName(widget.address!);
      setState(() {
        _checksum = name;
        _prevAddress = widget.address;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadChecksum();
    final isReady = widget.address != null && _checksum != null;

    quantusPrint('[PredictedAddressSection] address: ${widget.address}');
    quantusPrint('[PredictedAddressSection] checksum: $_checksum');
    quantusPrint('[PredictedAddressSection] isReady: $isReady');

    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.l10n.multisigCreatePredictedAddressLabel,
            style: text.labelData.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          if (widget.isLoading)
            const Skeleton(height: 20)
          else if (isReady) ...[
            Text(_checksum!, style: text.body.copyWith(color: colors.semanticLilac)),
            const SizedBox(height: 4),
            Text(widget.address!, style: text.dataAddressLarge.copyWith(color: colors.textContent)),
          ] else
            Text(
              widget.l10n.multisigCreatePredictedAddressPlaceholder,
              style: text.caption.copyWith(color: colors.textMuted),
            ),
        ],
      ),
    );
  }
}
