import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
import 'package:resonance_network_wallet/v2/components/multisig_threshold_slider.dart';
import 'package:resonance_network_wallet/v2/components/name_field.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/multisig_submission_service.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
  String? _signerFieldError;
  int _predictSeq = 0;

  String? _creatorAccountId;
  String? _creatorChecksum;

  @override
  void initState() {
    super.initState();
    final multisigCount = ref.read(multisigAccountsProvider).value?.length ?? 0;
    final l10n = ref.read(l10nProvider);
    _accountName.text = l10n.multisigCreateDefaultName(multisigCount + 1);
    _accountName.addListener(() => setState(() {}));
    _signerAddressController.addListener(_onSignerFieldChanged);

    final creator = _resolveCreatorAccount();
    if (creator != null) {
      _creatorAccountId = creator.accountId;
      _loadCreatorChecksum(creator.accountId);
    }
    _threshold = MultisigService.defaultThreshold(_allSigners.length);
    if (_hasMinimumSigners) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPredictedAddress());
    }
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
    final creator = _creatorAccountId;
    if (creator == null) return List<String>.from(_additionalSigners);
    return [creator, ..._additionalSigners];
  }

  bool get _hasMinimumSigners => _allSigners.length >= 2;

  bool get _isDisabled =>
      _accountName.text.trim().isEmpty || !_hasMinimumSigners || _creatorAccountId == null || _isLoading;

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
    if (address == _creatorAccountId || _additionalSigners.contains(address)) {
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
      }
    });
    _refreshPredictedAddress();
  }

  void _onThresholdChanged(int value) {
    setState(() => _threshold = value);
    _refreshPredictedAddress();
  }

  Future<void> _refreshPredictedAddress() async {
    if (!_hasMinimumSigners) {
      _predictSeq++;
      setState(() {
        _predictedAddress = null;
        _isPredictingAddress = false;
      });
      return;
    }

    final seq = ++_predictSeq;
    setState(() => _isPredictingAddress = true);
    try {
      final address = await ref
          .read(multisigServiceProvider)
          .predictMultisigAddress(
            signers: _allSigners,
            threshold: _threshold,
            nonce: MultisigService.defaultMultisigNonce,
          );
      if (!mounted || seq != _predictSeq) return;
      setState(() {
        _predictedAddress = address;
        _isPredictingAddress = false;
      });
    } catch (_) {
      if (!mounted || seq != _predictSeq) return;
      setState(() {
        _predictedAddress = null;
        _isPredictingAddress = false;
      });
    }
  }

  Future<void> _createMultisig() async {
    final creator = _resolveCreatorAccount();
    if (creator == null || !_hasMinimumSigners) return;

    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigCreateAuthReason);
    if (!authed) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await ref
          .read(multisigSubmissionServiceProvider)
          .startMultisigCreation(
            name: _accountName.text.trim(),
            signers: _allSigners,
            threshold: _threshold,
            creator: creator,
          );

      if (!mounted) return;
      context.showInfoToaster(message: l10n.multisigCreateSubmittedToast);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on MultisigAlreadyExistsException {
      if (mounted) {
        context.showErrorToaster(message: l10n.multisigCreateAlreadyExists);
      }
    } catch (_) {
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
    final colors = context.colors;
    final text = context.themeText;

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
              colors: colors,
              text: text,
              creatorAccountId: _creatorAccountId,
              creatorChecksum: _creatorChecksum,
              additionalSigners: _additionalSigners,
              signerAddressController: _signerAddressController,
              signerFieldError: _signerFieldError,
              onAddSigner: _addSigner,
              onRemoveSigner: _removeSigner,
            ),
            const SizedBox(height: 28),
            MultisigThresholdSlider(
              threshold: _allSigners.isEmpty ? 1 : _threshold.clamp(1, _allSigners.length),
              signerCount: _allSigners.length,
              label: l10n.multisigCreateThresholdLabel,
              valueLabel: l10n.multisigCreateThresholdValue(
                _allSigners.isEmpty ? 1 : _threshold.clamp(1, _allSigners.length),
                _allSigners.length,
              ),
              onChanged: _onThresholdChanged,
            ),
            const SizedBox(height: 28),
            _PredictedAddressSection(
              l10n: l10n,
              colors: colors,
              text: text,
              isLoading: _isPredictingAddress,
              address: _predictedAddress,
            ),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.multisigCreateButton,
          onTap: _createMultisig,
          isLoading: _isLoading,
          isDisabled: _isDisabled,
        ),
      ),
    );
  }
}

class _SignersSection extends StatelessWidget {
  const _SignersSection({
    required this.l10n,
    required this.colors,
    required this.text,
    required this.creatorAccountId,
    required this.creatorChecksum,
    required this.additionalSigners,
    required this.signerAddressController,
    required this.signerFieldError,
    required this.onAddSigner,
    required this.onRemoveSigner,
  });

  final AppLocalizations l10n;
  final AppColorsV2 colors;
  final AppTextTheme text;
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigCreateSignersLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 8),
          Text(l10n.multisigCreateSignersSubtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 16),
          if (creatorAccountId != null)
            MultisigSignerListTile(
              accountId: creatorAccountId!,
              checksum: creatorChecksum,
              isYou: true,
              youLabel: l10n.multisigYouLabel,
              colors: colors,
              text: text,
            ),
          ...additionalSigners.map(
            (address) => MultisigSignerListTile(
              accountId: address,
              onRemove: () => onRemoveSigner(address),
              colors: colors,
              text: text,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 48,
            decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.person_add_outlined, size: 16, color: colors.textLabel),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: signerAddressController,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(hintText: l10n.multisigCreateAddSignerHint, border: InputBorder.none),
                    onSubmitted: (_) => onAddSigner(),
                  ),
                ),
              ],
            ),
          ),
          if (signerFieldError != null) ...[
            const SizedBox(height: 8),
            Text(signerFieldError!, style: text.detail?.copyWith(color: colors.textError)),
          ],
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

class _PredictedAddressSection extends StatelessWidget {
  const _PredictedAddressSection({
    required this.l10n,
    required this.colors,
    required this.text,
    required this.isLoading,
    required this.address,
  });

  final AppLocalizations l10n;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final bool isLoading;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.multisigCreatePredictedAddressLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 12),
          if (isLoading)
            const Skeleton(height: 20)
          else if (address != null)
            Text(
              address!,
              style: text.smallParagraph?.copyWith(
                color: colors.textPrimary,
                fontFamily: AppTextTheme.fontFamilySecondary,
              ),
            )
          else
            Text(
              l10n.multisigCreatePredictedAddressPlaceholder,
              style: text.detail?.copyWith(color: colors.textTertiary),
            ),
        ],
      ),
    );
  }
}
