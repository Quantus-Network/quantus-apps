import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/opt_in_position_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

void showCompleteSetupActionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CompleteSetupActionSheet(),
  );
}

class CompleteSetupActionSheet extends ConsumerStatefulWidget {
  const CompleteSetupActionSheet({super.key});

  @override
  ConsumerState<CompleteSetupActionSheet> createState() => _CompleteSetupActionSheetState();
}

class _CompleteSetupActionSheetState extends ConsumerState<CompleteSetupActionSheet> {
  final _taskmasterService = TaskmasterService();
  final _ethAddressController = TextEditingController();
  final _xHandleController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasInitialized = false;
  String? _originalEthAddress;
  String? _originalXUsername;

  bool get _isBioValid => _bioController.text.trim().toLowerCase().contains('@quantusnetwork');

  @override
  void dispose() {
    _ethAddressController.dispose();
    _xHandleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _initializeData(AccountAssociations associations) {
    if (_hasInitialized) return;

    _originalEthAddress = associations.ethAddress;
    _originalXUsername = associations.xUsername;

    if (associations.ethAddress != null) {
      _ethAddressController.text = associations.ethAddress!;
    }
    if (associations.xUsername != null) {
      _xHandleController.text = associations.xUsername!;
    }

    _hasInitialized = true;
  }

  Future<void> _handleLinkAccounts() async {
    final ethAddress = _ethAddressController.text.trim();
    final xHandle = _xHandleController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final optInStatus = ref.read(optInPositionProvider);
      final isAlreadyOptedIn = optInStatus.maybeWhen(data: (position) => position.position > 0, orElse: () => false);

      if (!isAlreadyOptedIn) {
        await _taskmasterService.optInRewardProgram();
      }

      if (ethAddress.isNotEmpty && ethAddress != _originalEthAddress) {
        await _taskmasterService.associateEthAddress(ethAddress);
      }

      final normalizedHandle = xHandle.startsWith('@') ? xHandle.substring(1) : xHandle;
      if (normalizedHandle.isNotEmpty && normalizedHandle != _originalXUsername) {
        await _taskmasterService.associateXHandle(normalizedHandle);
      }

      ref.invalidate(accountAssociationsProvider);
      ref.invalidate(optInPositionProvider);

      if (mounted) {
        context.showSuccessToaster(message: 'Accounts linked successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(accountAssociationsProvider);

    associationsAsync.whenData((associations) {
      _initializeData(associations);
    });

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(left: 26, right: 26, top: 40, bottom: 40 + MediaQuery.of(context).viewInsets.bottom),
      decoration: ShapeDecoration(
        color: context.themeColors.background2,
        shape: const RoundedRectangleBorder(
          side: BorderSide(width: 1, strokeAlign: BorderSide.strokeAlignOutside, color: Color(0x66F4F6F9)),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 64),
            _buildForm(),
            const SizedBox(height: 32),
            _buildLinkButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACCOUNT SETUP', style: context.themeText.paragraph),
                const SizedBox(height: 6),
                SizedBox(
                  width: 264,
                  child: Text(
                    'Link your accounts once to participate in referrals and raids.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          // Close button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, color: context.themeColors.textPrimary, size: 24),
          ),
        ],
      ),
    );
  }

  void _showUnlinkConfirmation({required String title, required Future<void> Function() onConfirm}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: context.themeColors.background2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) =>
          _UnlinkConfirmationSheet(title: title, onConfirm: onConfirm, dangerColor: context.themeColors.buttonDanger),
    );
  }

  Future<void> _handleUnlinkEth() async {
    await _taskmasterService.dissociateEthAddress();
    _ethAddressController.clear();
    _originalEthAddress = null;
    ref.invalidate(accountAssociationsProvider);
    if (mounted) {
      context.showSuccessToaster(message: 'ETH address unlinked');
      setState(() {});
    }
  }

  Future<void> _handleUnlinkX() async {
    await _taskmasterService.dissociateXAccount();
    _xHandleController.clear();
    _originalXUsername = null;
    ref.invalidate(accountAssociationsProvider);
    if (mounted) {
      context.showSuccessToaster(message: 'X account unlinked');
      setState(() {});
    }
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputSection(
          title: 'Connect your wallet',
          controller: _ethAddressController,
          hintText: 'Enter ETH Address',
          canUnlink: _originalEthAddress != null,
          onUnlink: () => _showUnlinkConfirmation(title: 'ETH Address', onConfirm: _handleUnlinkEth),
        ),
        const SizedBox(height: 32),
        _buildInputSection(
          title: 'Connect your X handle',
          controller: _xHandleController,
          hintText: 'Enter username',
          canUnlink: _originalXUsername != null,
          onUnlink: () => _showUnlinkConfirmation(title: 'X Account', onConfirm: _handleUnlinkX),
        ),
        const SizedBox(height: 32),
        _buildBioSection(),
      ],
    );
  }

  Widget _buildInputSection({
    required String title,
    required TextEditingController controller,
    required String hintText,
    bool canUnlink = false,
    VoidCallback? onUnlink,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 323,
            child: Text(title, style: context.themeText.smallTitle?.copyWith(color: context.themeColors.textPrimary)),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: ShapeDecoration(
              color: const Color(0x0AF4F6F9),
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0x19F4F6F9)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    style: const TextStyle(
                      color: Color(0xFFF4F6F9),
                      fontSize: 14,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '|$hintText',
                      hintStyle: const TextStyle(
                        color: Color(0x7FF4F6F9),
                        fontSize: 14,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (canUnlink)
                  GestureDetector(
                    onTap: onUnlink,
                    child: Icon(Icons.close, size: 18, color: context.themeColors.buttonDanger),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 323,
                  child: Text(
                    'Verify your X account',
                    style: context.themeText.smallTitle?.copyWith(color: context.themeColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                const SizedBox(
                  width: 323,
                  child: Text(
                    'To confirm this account belongs to you, please update your X bio to include @QuantusNetwork',
                    style: TextStyle(
                      color: Color(0x7FF4F6F9),
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: ShapeDecoration(
              color: const Color(0x0AF4F6F9),
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0x19F4F6F9)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: TextField(
              controller: _bioController,
              onChanged: (_) => setState(() {}),
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(
                color: Color(0xFFF4F6F9),
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration.collapsed(
                hintText: '|Updated Bio',
                hintStyle: TextStyle(
                  color: Color(0x7FF4F6F9),
                  fontSize: 14,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton() {
    final bool isEnabled = _isBioValid && !_isSubmitting;

    return GestureDetector(
      onTap: isEnabled ? _handleLinkAccounts : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.40,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: ShapeDecoration(
            gradient: const LinearGradient(
              begin: Alignment(0.02, 0.50),
              end: Alignment(1.00, 0.50),
              colors: [Color(0x7F0000FF), Color(0x19ED4CCE), Color(0x7FFFE91F)],
            ),
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0x33F4F6F9)),
              borderRadius: BorderRadius.circular(42),
            ),
          ),
          child: Center(
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: context.themeColors.textPrimary, strokeWidth: 2),
                  )
                : Text(
                    'Link Accounts',
                    style: context.themeText.smallTitle?.copyWith(color: context.themeColors.textPrimary),
                  ),
          ),
        ),
      ),
    );
  }
}

class _UnlinkConfirmationSheet extends StatefulWidget {
  final String title;
  final Future<void> Function() onConfirm;
  final Color dangerColor;

  const _UnlinkConfirmationSheet({required this.title, required this.onConfirm, required this.dangerColor});

  @override
  State<_UnlinkConfirmationSheet> createState() => _UnlinkConfirmationSheetState();
}

class _UnlinkConfirmationSheetState extends State<_UnlinkConfirmationSheet> {
  bool _isUnlinking = false;

  Future<void> _handleUnlink() async {
    setState(() => _isUnlinking = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isUnlinking = false);
        context.showErrorToaster(message: 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Unlink ${widget.title}?', style: context.themeText.smallTitle?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to unlink your ${widget.title}?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontFamily: 'Inter'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _isUnlinking ? null : _handleUnlink,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: ShapeDecoration(
                  color: widget.dangerColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(42)),
                ),
                alignment: Alignment.center,
                child: _isUnlinking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Unlink',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isUnlinking ? null : () => Navigator.pop(context),
              child: Opacity(
                opacity: _isUnlinking ? 0.5 : 1.0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: ShapeDecoration(
                    color: const Color(0x33F4F6F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(42)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFFF4F6F9),
                      fontSize: 16,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
