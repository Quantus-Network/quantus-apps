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
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signature_scan_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Shows an unsigned transaction as a Keystone UR QR, then scans its signature.
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
    } catch (error, stackTrace) {
      quantusDebugPrint('Keystone payload preparation failed: $error');
      TelemetryService().sendError('Keystone payload preparation failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = ref.read(l10nProvider).keystoneSignError);
    }
  }

  Future<void> _goToScan() async {
    final unsignedData = _unsignedData;
    if (unsignedData == null) return;
    final hash = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => KeystoneSignatureScanScreen(session: widget.session, unsignedData: unsignedData),
      ),
    );
    if (hash != null && mounted) Navigator.pop(context, hash);
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

  Widget _details(AppColorsV2 colors, AppTextTheme text, KeystoneSigningSession session) {
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
