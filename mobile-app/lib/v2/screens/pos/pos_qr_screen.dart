import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/pos_service.dart';
import 'package:resonance_network_wallet/services/tx_watch_service.dart';
import 'package:resonance_network_wallet/v2/screens/pos/pos_amount_screen.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class PosQrScreen extends ConsumerStatefulWidget {
  final String amount;
  const PosQrScreen({super.key, required this.amount});

  @override
  ConsumerState<PosQrScreen> createState() => _PosQrScreenState();
}

class _PosQrScreenState extends ConsumerState<PosQrScreen> {
  final _posService = PosService();
  final _fmt = NumberFormattingService();
  PosPaymentRequest? _request;

  final _txWatch = TxWatchService();
  Timer? _startTimer;
  Timer? _timeoutTimer;
  TxWatchTransfer? _paidTransfer;
  bool _watching = false;
  String? _watchError;
  bool get _isPaid => _paidTransfer != null;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(const Duration(milliseconds: 500), _startWatching);
  }

  void _startWatching() {
    final active = ref.read(activeAccountProvider).value;
    if (active == null) return;

    final expectedPlanck = _fmt.parseAmount(widget.amount);
    setState(() {
      _watching = true;
      _watchError = null;
    });

    _txWatch.watch(
      address: active.account.accountId,
      onTransfer: (tx) {
        if (_isPaid) return;
        final received = BigInt.tryParse(tx.amount);
        if (expectedPlanck != null && received == expectedPlanck) {
          _timeoutTimer?.cancel();
          if (mounted) setState(() => _paidTransfer = tx);
        }
      },
      onError: (e) {
        _txWatch.dispose();
        _timeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _watching = false;
            _watchError = 'Connection lost. Tap to retry.';
          });
        }
      },
    );

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      _txWatch.dispose();
      if (mounted) {
        setState(() {
          _watching = false;
          _watchError = 'Timed out. Tap to retry.';
        });
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _timeoutTimer?.cancel();
    _txWatch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final accountAsync = ref.watch(activeAccountProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: _isPaid ? 'Payment Received' : 'Scan to Pay'),
      child: accountAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: colors.textPrimary)),
        error: (e, _) => Center(
          child: Text('Error: $e', style: text.detail?.copyWith(color: colors.textError)),
        ),
        data: (active) {
          if (active == null) return const Center(child: Text('No active account'));
          _request ??= _posService.createPaymentRequest(accountId: active.account.accountId, amount: widget.amount);
          if (_isPaid) return _buildPaidContent(colors, text);
          return _buildQrContent(_request!, colors, text);
        },
      ),
    );
  }

  Widget _buildPaidContent(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const Spacer(),
        Icon(Icons.check_circle_rounded, color: colors.accentGreen, size: 96),
        const SizedBox(height: 24),
        Text('Paid', style: text.extraLargeTitle?.copyWith(color: colors.accentGreen, fontSize: 48)),
        const SizedBox(height: 16),
        Text(
          '${widget.amount} ${AppConstants.tokenSymbol}',
          style: text.mediumTitle?.copyWith(color: colors.textSecondary),
        ),
        const Spacer(),
        GlassButton.simple(label: 'Done', onTap: _newCharge, variant: ButtonVariant.primary),
        const SizedBox(height: 24),
      ],
    );
  }

  void _newCharge() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosAmountScreen()));
  }

  Widget _buildQrContent(PosPaymentRequest request, AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const Spacer(),
        Text(
          '${request.amount} ${AppConstants.tokenSymbol}',
          style: text.extraLargeTitle?.copyWith(color: colors.textPrimary, fontSize: 40),
        ),
        const SizedBox(height: 32),
        _buildQrCode(request.paymentUrl, colors),
        const SizedBox(height: 12),
        // GestureDetector(
        //   onTap: () => Clipboard.setData(ClipboardData(text: request.paymentUrl)),
        //   child: Text(
        //     'Copy Link',
        //     style: text.detail?.copyWith(color: colors.textTertiary, decoration: TextDecoration.underline),
        //   ),
        // ),
        // const SizedBox(height: 8),
        Text('Ref: ${request.refId}', style: text.detail?.copyWith(color: colors.textTertiary)),
        const Spacer(),
        GlassButton.simple(label: 'New Charge', onTap: _newCharge, variant: ButtonVariant.secondary),
        const SizedBox(height: 16),
        _buildWaitingButton(colors, text),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildWaitingButton(AppColorsV2 colors, AppTextTheme text) {
    if (_watching) {
      return GlassButton(
        variant: ButtonVariant.primary,
        onTap: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: colors.textSecondary, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Waiting for payment', style: text.smallTitle?.copyWith(color: colors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_watchError != null) ...[
          Text('Network Error', style: text.detail?.copyWith(color: colors.textError)),
          const SizedBox(height: 8),
          GlassButton.simple(label: 'Try Again', onTap: _startWatching, variant: ButtonVariant.secondary),
          const SizedBox(height: 12),
        ],
        GlassButton.simple(label: 'Done', onTap: _newCharge, variant: ButtonVariant.primary),
      ],
    );
  }

  Widget _buildQrCode(String data, AppColorsV2 colors) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 280,
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
        ),
      ),
    );
  }
}
