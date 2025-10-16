import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

class AccountCopyActionSheet extends StatefulWidget {
  final Account activeAccount;

  const AccountCopyActionSheet({super.key, required this.activeAccount});

  @override
  State<AccountCopyActionSheet> createState() => _AccountCopyActionSheetState();
}

class _AccountCopyActionSheetState extends State<AccountCopyActionSheet> {
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  String? _checksum;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChecksum();
  }

  Future<void> _loadChecksum() async {
    try {
      final checksum = await _checksumService.getHumanReadableName(
        widget.activeAccount.accountId,
      );
      setState(() {
        _checksum = checksum;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading checksum: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyAddress() {
    ClipboardExtensions.copyTextWithSnackbar(
      context,
      widget.activeAccount.accountId,
    );
    Navigator.pop(context);
  }

  void _copyChecksum() {
    if (_checksum != null) {
      ClipboardExtensions.copyTextWithSnackbar(
        context,
        _checksum!,
        message: 'Checkphrase copied to clipboard',
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 140,
      padding: const EdgeInsets.only(top: 10, left: 34, right: 10, bottom: 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.9)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _copyAddress,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Copy Address',
                style: context.themeText.paragraph?.copyWith(
                  color: context.themeColors.light,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: _isLoading ? null : _copyChecksum,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _isLoading ? 'Loading...' : 'Copy Checkphrase',
                style: context.themeText.paragraph?.copyWith(
                  color: _isLoading
                      ? context.themeColors.textSecondary
                      : context.themeColors.light,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showAccountCopyActionSheet(BuildContext context, Account activeAccount) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => AccountCopyActionSheet(activeAccount: activeAccount),
  );
}
