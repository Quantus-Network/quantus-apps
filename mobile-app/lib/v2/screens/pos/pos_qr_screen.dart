import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/pos_service.dart';
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
  PosPaymentRequest? _request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final accountAsync = ref.watch(activeAccountProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Scan to Pay'),
      child: accountAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: colors.textPrimary)),
        error: (e, _) => Center(
          child: Text('Error: $e', style: text.detail?.copyWith(color: colors.textError)),
        ),
        data: (active) {
          if (active == null) return const Center(child: Text('No active account'));
          _request ??= _posService.createPaymentRequest(accountId: active.account.accountId, amount: widget.amount);
          debugPrint('POS Payment URL: ${_request!.paymentUrl}');
          return _buildContent(_request!, colors, text);
        },
      ),
    );
  }

  Widget _buildContent(PosPaymentRequest request, AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const Spacer(),
        Text(
          '${request.amount} ${AppConstants.tokenSymbol}',
          style: text.extraLargeTitle?.copyWith(color: colors.textPrimary, fontSize: 40),
        ),
        const SizedBox(height: 32),
        _buildQrCode(request.paymentUrl, colors),
        const SizedBox(height: 16),
        Text('Ref: ${request.refId}', style: text.detail?.copyWith(color: colors.textTertiary)),
        const Spacer(),
        GlassButton.simple(label: 'New Charge', onTap: () => Navigator.pop(context), variant: ButtonVariant.secondary),
        const SizedBox(height: 16),
        GlassButton.simple(
          label: 'Done',
          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          variant: ButtonVariant.primary,
        ),
        const SizedBox(height: 24),
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
