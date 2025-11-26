import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/card_info.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _referralService = ReferralService();
  final _referralCodeController = TextEditingController();

  bool _isSubmitting = false;
  String? _checksum;
  bool _loading = true;
  String? _errorMsg;
  bool _isDisabled = true;

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _referralService.submitReferralToBackend(referral: _referralCodeController.text);

      setState(() {
        _isSubmitting = false;
        _checksum = _referralCodeController.text;
      });
    } catch (e) {
      print('Failed submitting referral code: $e');

      setState(() {
        _isSubmitting = false;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _loadReferralData() async {
    _checksum = await _referralService.getReferralData();

    setState(() {
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    _loadReferralData();

    _referralCodeController.addListener(() {
      setState(() {
        _isDisabled = _referralCodeController.text.trim().isEmpty;
        _errorMsg = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: WalletAppBar(title: 'Referral'),
      decorations: [
        const Positioned(left: -80, top: 150, child: Sphere(variant: 7, size: 248)),
        const Positioned(right: -50, bottom: 100, child: Sphere(variant: 2, size: 194)),
      ],
      child: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_checksum == null) return _buildFormWidget(context);

    return _buildReferrerInfo(context);
  }

  Widget _buildReferrerInfo(BuildContext context) {
    return Column(
      children: [
        CardInfo(text: _checksum!, label: 'Referrer Code', onPressed: () {}, textColor: context.themeColors.yellow),
      ],
    );
  }

  Widget _buildFormWidget(BuildContext context) {
    return Column(
      children: [
        CustomTextField(controller: _referralCodeController, labelText: 'Referral Code', errorMsg: _errorMsg),
        const SizedBox(height: 28),
        SizedBox(
          width: context.isTablet ? 465 : 305,
          child: Button(
            label: 'Submit',
            isLoading: _isSubmitting,
            isDisabled: _isDisabled,
            variant: ButtonVariant.primary,
            onPressed: _handleSubmit,
          ),
        ),
      ],
    );
  }
}
