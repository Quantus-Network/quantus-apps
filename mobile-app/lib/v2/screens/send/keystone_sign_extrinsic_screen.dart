import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
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
import 'package:resonance_network_wallet/v2/screens/send/keystone_extrinsic_session.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_scan_extrinsic_signature_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Shows an unsigned extrinsic as a Keystone UR QR for an arbitrary call.
///
/// Pops with `true` when the signature was scanned and the extrinsic submitted
/// successfully (see [KeystoneScanExtrinsicSignatureScreen]).
class KeystoneSignExtrinsicScreen extends ConsumerStatefulWidget {
  final KeystoneExtrinsicSession session;

  const KeystoneSignExtrinsicScreen({super.key, required this.session});

  @override
  ConsumerState<KeystoneSignExtrinsicScreen> createState() => _KeystoneSignExtrinsicScreenState();
}

class _KeystoneSignExtrinsicScreenState extends ConsumerState<KeystoneSignExtrinsicScreen> {
  UnsignedTransactionData? _unsignedData;
  List<String>? _urParts;
  String? _error;

  KeystoneSignCacheKey? get _cacheKey {
    final identity = widget.session.cacheIdentity;
    if (identity == null) return null;
    return KeystoneSignCacheKey.forExtrinsic(
      accountId: widget.session.account.accountId,
      identity: identity,
    );
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final cacheKey = _cacheKey;
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
      final call = widget.session.buildCall();
      final unsigned = await substrate.getUnsignedTransactionPayload(widget.session.account, call);
      final parts = encodeUr(data: unsigned.encodedPayloadRaw);
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
    } catch (e, st) {
      quantusDebugPrint('Keystone extrinsic payload preparation failed: $e');
      TelemetryService().sendError('Keystone extrinsic payload preparation failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _error = ref.read(l10nProvider).keystoneSignError);
    }
  }

  Future<void> _goToScan() async {
    final unsignedData = _unsignedData;
    if (unsignedData == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => KeystoneScanExtrinsicSignatureScreen(
          session: widget.session,
          unsignedData: unsignedData,
        ),
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final session = widget.session;

    return ScaffoldBase(
      appBar: V2AppBar(title: session.title),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(l10n.keystoneSignTitle, style: text.smallTitle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.keystoneSignInstruction,
            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
            textAlign: TextAlign.center,
          ),
          if (session.primaryDetail != null || session.secondaryDetail != null || session.tertiaryDetail != null) ...[
            const SizedBox(height: 24),
            _details(colors, text, session),
          ],
          const SizedBox(height: 24),
          Expanded(child: Center(child: _buildQr(colors, text))),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.keystoneSignNext,
          variant: ButtonVariant.primary,
          isDisabled: _unsignedData == null,
          onTap: _goToScan,
        ),
      ),
    );
  }

  Widget _details(AppColorsV2 colors, AppTextTheme text, KeystoneExtrinsicSession session) {
    return Column(
      children: [
        if (session.primaryDetail != null)
          Text(
            session.primaryDetail!,
            style: text.smallTitle?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
        if (session.secondaryDetail != null) ...[
          const SizedBox(height: 8),
          Text(
            session.secondaryDetail!,
            style: text.detail?.copyWith(
              color: colors.textMuted,
              fontFamily: AppTextTheme.fontFamilySecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (session.tertiaryDetail != null) ...[
          const SizedBox(height: 4),
          Text(
            session.tertiaryDetail!,
            style: text.smallParagraph?.copyWith(color: colors.checksum, height: 1.2),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildQr(AppColorsV2 colors, AppTextTheme text) {
    final error = _error;
    if (error != null) {
      return Text(
        error,
        style: text.detail?.copyWith(color: colors.textError),
        textAlign: TextAlign.center,
      );
    }
    final parts = _urParts;
    if (parts == null) return const Loader();
    return AnimatedUrQr(parts: parts);
  }
}
