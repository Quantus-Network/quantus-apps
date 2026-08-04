import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/animated_ur_qr.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_widgets.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_verify_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Step 1/3 of Keystone signing: shows the unsigned transaction as an
/// animated UR QR for the device to scan.
///
/// The runtime call, display details, caching, and submission behavior come from
/// [session], so every Keystone-backed flow shares this screen.
/// Pops with the submitted extrinsic hash.
class KeystoneSignScreen extends ConsumerStatefulWidget {
  final KeystoneSigningSession session;

  const KeystoneSignScreen({super.key, required this.session});

  @override
  ConsumerState<KeystoneSignScreen> createState() => _KeystoneSignScreenState();
}

class _KeystoneSignScreenState extends ConsumerState<KeystoneSignScreen> {
  /// Bytes per QR frame for the animated payload. The Keystone device scans
  /// this QR, so frames must stay easy to read. SCALE-encoded transactions are
  /// ~300 bytes, so 400-byte fragments put a typical transaction in a single
  /// static QR (~version 21, well within Keystone's range).
  static const _kUrFragmentLength = 400;

  UnsignedTransactionData? _unsignedData;
  List<String>? _urParts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final cacheKey = widget.session.cacheKey;
    if (cacheKey != null) {
      final cached = ref.read(keystoneSignCacheProvider.notifier).lookup(cacheKey);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _unsignedData = cached.unsignedData;
          _urParts = cached.urParts;
        });
        return;
      }
    }

    try {
      final substrate = ref.read(substrateServiceProvider);
      final unsigned = await substrate.getUnsignedTransactionPayload(
        widget.session.account,
        widget.session.buildCall(),
      );
      final parts = encodeUr(data: unsigned.encodedPayloadRaw, maxFragmentLength: _kUrFragmentLength);
      if (parts.isEmpty) throw Exception('Failed to encode transaction payload as UR');
      if (cacheKey != null) {
        ref.read(keystoneSignCacheProvider.notifier).store(key: cacheKey, unsignedData: unsigned, urParts: parts);
      }
      TelemetryService().sendEvent('${widget.session.telemetryPrefix}_payload_ready');
      if (!mounted) return;
      setState(() {
        _unsignedData = unsigned;
        _urParts = parts;
      });
    } catch (error) {
      quantusPrint('Keystone payload preparation failed: $error');
      TelemetryService().sendError('Keystone payload preparation failed', error: error);
      if (!mounted) return;
      setState(() => _error = ref.read(l10nProvider).keystoneSignError);
    }
  }

  Future<void> _goToVerify() async {
    final unsignedData = _unsignedData;
    if (unsignedData == null) return;
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => KeystoneVerifyScreen(session: widget.session, unsignedData: unsignedData),
      ),
    );
    if (!mounted) return;
    // A hash means the signature was submitted; `false` means the user rejected
    // the transaction on the device — either way this flow is over.
    if (result is String) Navigator.pop(context, result);
    if (result == false) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final session = widget.session;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.keystoneSignScreenTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KeystoneStepLabel(current: 1, total: 3),
            const SizedBox(height: 12),
            Text(l10n.keystoneSignTitle, style: text.paragraph?.copyWith(color: colors.textPrimary, height: 1.0)),
            const SizedBox(height: 8),
            Text(l10n.keystoneSignInstruction, style: text.detail?.copyWith(color: colors.textSubtle, height: 1.35)),
            const SizedBox(height: 32),
            Center(child: _buildQr(colors, text)),
            if (session.primaryDetail != null || session.secondaryDetail != null) ...[
              const SizedBox(height: 32),
              _details(colors, text, l10n, session),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(label: l10n.keystoneSignNext, isDisabled: _unsignedData == null, onTap: _goToVerify),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.keystoneSignCancel,
              variant: ButtonVariant.underline,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n, KeystoneSigningSession session) {
    final labelStyle = text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary);
    final valueStyle = text.transactionDetailRowValue?.copyWith(
      color: colors.textPrimary.useOpacity(0.8),
      fontWeight: FontWeight.w400,
    );
    final secondary = session.secondaryDetail?.trim();
    final displaySecondary = secondary != null && SubstrateService().isValidSS58Address(secondary)
        ? AddressFormattingService.formatAddress(secondary)
        : secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.keystoneSignYouAreSigning,
          style: text.detail?.copyWith(fontFamily: AppTextTheme.fontFamilySecondary, color: colors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (session.primaryDetail != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.sendReviewAmount.toUpperCase(), style: labelStyle),
                Text(session.primaryDetail!, style: valueStyle),
              ],
            ),
          ),
        if (session.primaryDetail != null && session.secondaryDetail != null)
          Divider(height: 1, color: colors.separator),
        if (secondary != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.sendReviewTo.toUpperCase(), style: labelStyle),
                const SizedBox(width: 24),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        displaySecondary!,
                        style: text.transactionDetailRowValue?.copyWith(height: 1.35),
                        textAlign: TextAlign.end,
                      ),
                      if (session.tertiaryDetail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          session.tertiaryDetail!,
                          style: text.detail?.copyWith(color: colors.checksum),
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQr(AppColorsV2 colors, AppTextTheme text) {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(
          error,
          style: text.detail?.copyWith(color: colors.textError),
          textAlign: TextAlign.center,
        ),
      );
    }
    final parts = _urParts;
    if (parts == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Loader());
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.textTertiary),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedUrQr(parts: parts, size: 267),
    );
  }
}
