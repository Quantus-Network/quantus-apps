import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_widgets.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_verify_screen.dart';

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
  UnsignedTransactionData? _unsignedData;
  List<String>? _urParts;
  DateTime? _payloadStoredAt;
  Timer? _freshnessTimer;
  bool _preparing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshIfStale());
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  /// True once the payload's era reserve is consumed: the remaining lifetime
  /// no longer covers a full device scan/verify/sign/submit round trip.
  bool get _payloadStale {
    final unsignedData = _unsignedData;
    final storedAt = _payloadStoredAt;
    if (unsignedData == null || storedAt == null) return false;
    return DateTime.now().difference(storedAt) >= keystoneSignCacheMaxAge(unsignedData.payloadToSign);
  }

  void _refreshIfStale() {
    if (_payloadStale) _prepare();
  }

  Future<void> _prepare() async {
    if (_preparing) return;
    _preparing = true;
    try {
      final payload = await ensureKeystoneSignPayload(
        ref,
        account: widget.session.account,
        buildCall: widget.session.buildCall,
        cacheKey: widget.session.cacheKey,
      );
      TelemetryService().sendEvent('${widget.session.telemetryPrefix}_payload_ready');
      if (!mounted) return;
      setState(() {
        _unsignedData = payload.unsignedData;
        _urParts = payload.urParts;
        _payloadStoredAt = payload.storedAt;
      });
    } catch (error) {
      quantusPrint('Keystone payload preparation failed: $error');
      TelemetryService().sendError('Keystone payload preparation failed', error: error);
      if (!mounted) return;
      setState(() => _error = ref.read(l10nProvider).keystoneSignError);
    } finally {
      _preparing = false;
    }
  }

  Future<void> _goToVerify() async {
    final unsignedData = _unsignedData;
    if (unsignedData == null) return;
    // Never carry a nearly expired payload into the verify/sign/submit steps —
    // rebuild the QR instead, so the device has to rescan a fresh payload.
    if (_payloadStale) {
      quantusPrint('Keystone payload stale on advance, regenerating');
      _prepare();
      return;
    }
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final session = widget.session;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.keystoneSignScreenTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KeystoneStepLabel(current: 1, total: 3),
            const SizedBox(height: 12),
            Text(l10n.keystoneSignTitle, style: text.headingRow.copyWith(color: colors.textContent)),
            const SizedBox(height: 8),
            Text(l10n.keystoneSignInstruction, style: text.caption.copyWith(color: colors.textMuted)),
            const SizedBox(height: 32),
            Center(child: _buildQr(colors, text)),
            if (session.primaryDetail != null || session.secondaryDetail != null) ...[
              const SizedBox(height: 32),
              _details(l10n, session),
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

  Widget _details(AppLocalizations l10n, KeystoneSigningSession session) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final secondary = session.secondaryDetail?.trim();
    final displaySecondary = secondary != null && SubstrateService().isValidSS58Address(secondary)
        ? AddressFormattingService.formatAddress(secondary)
        : secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.keystoneSignYouAreSigning, style: text.labelData.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        if (session.primaryDetail != null)
          DetailSummaryRow(label: l10n.sendReviewAmount.toUpperCase(), value: session.primaryDetail!),
        if (session.primaryDetail != null && session.secondaryDetail != null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: MenuDivider()),
        if (secondary != null)
          DetailSummaryRow(
            label: l10n.sendReviewTo.toUpperCase(),
            value: displaySecondary!,
            checkphrase: session.tertiaryDetail,
            monospace: true,
          ),
      ],
    );
  }

  Widget _buildQr(AppColorsV3 colors, AppTextThemeV3 text) {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(
          error,
          style: text.caption.copyWith(color: colors.semanticEmber),
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
        border: Border.all(color: colors.borderHairline),
        borderRadius: context.radiusV3.mdBorder,
      ),
      child: AnimatedUrQr(parts: parts, size: 267),
    );
  }
}
