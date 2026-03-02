import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/button_icon.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ReceiveSheet extends StatefulWidget {
  const ReceiveSheet({super.key});

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  String? _accountId;
  String? _checksum;
  Future<String>? _checksumFuture;

  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final account = (await _settingsService.getActiveAccount())!;
      setState(() {
        _accountId = account.account.accountId;
        _checksumFuture = _checksumService.getHumanReadableName(account.account.accountId);
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
    }
  }

  void _copyAddress() {
    if (_accountId != null) {
      context.copyTextWithToaster(_accountId!);
    }
  }

  void _copyChecksum() {
    if (_checksum != null) {
      context.copyTextWithToaster(_checksum!, message: 'Checkphrase copied');
    }
  }

  void _share() {
    if (_accountId != null) {
      shareAccountDetails(context, _accountId!, checksum: _checksum ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return BottomSheetContainer(
      title: 'Receive',
      child: _accountId == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: colors.textPrimary)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQrCode(colors),
                const SizedBox(height: 20),
                _buildAddress(colors, text),
                const SizedBox(height: 9),
                _buildChecksum(colors, text),
                const SizedBox(height: 32),
                _buildButtons(colors, text),
              ],
            ),
    );
  }

  Widget _buildQrCode(AppColorsV2 colors) {
    return SizedBox(
      width: 267,
      height: 267,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: QrImageView(
              data: _accountId!,
              version: QrVersions.auto,
              size: 267,
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            ),
          ),
          // Container(
          //   width: 40,
          //   height: 40,
          //   decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          //   child: ClipOval(child: AccountGradientImage(accountId: _accountId, width: 36.0, height: 36.0)),
          // ),
        ],
      ),
    );
  }

  Widget _buildAddress(AppColorsV2 colors, AppTextTheme text) {
    return InkWell(
      onTap: _copyAddress,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _accountId!,
              style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          _copyButton(colors),
        ],
      ),
    );
  }

  Widget _buildChecksum(AppColorsV2 colors, AppTextTheme text) {
    return FutureBuilder<String>(
      future: _checksumFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.textSecondary),
          );
        }
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) return const SizedBox.shrink();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_checksum != snapshot.data && mounted) setState(() => _checksum = snapshot.data!);
        });

        return InkWell(
          onTap: _copyChecksum,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  snapshot.data!,
                  style: text.detail?.copyWith(color: colors.accentPink),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              _copyButton(colors),
            ],
          ),
        );
      },
    );
  }

  Widget _copyButton(AppColorsV2 colors) {
    return const ButtonIcon.rounded(icon: Icons.copy, size: ButtonIconSize.small);
  }

  Widget _buildButtons(AppColorsV2 colors, AppTextTheme text) {
    return Row(
      children: [
        Expanded(
          child: Button(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            label: 'Copy',
            onTap: _copyAddress,
            icon: Icon(Icons.copy, size: 20, color: colors.textPrimary),
            iconPlacement: IconPlacement.leading,
            variant: ButtonVariant.secondary,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Button(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            label: 'Share',
            onTap: _share,
            icon: Icon(Icons.share, size: 20, color: colors.textPrimary),
            iconPlacement: IconPlacement.leading,
          ),
        ),
      ],
    );
  }
}

void showReceiveSheetV2(BuildContext context) {
  BottomSheetContainer.show(context, builder: (_) => const ReceiveSheet());
}
