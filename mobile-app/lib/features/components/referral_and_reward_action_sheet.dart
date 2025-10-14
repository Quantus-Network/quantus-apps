import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class ReferralAndRewardActionSheet extends StatefulWidget {
  final String? referralCode;

  const ReferralAndRewardActionSheet({super.key, this.referralCode});

  @override
  State<ReferralAndRewardActionSheet> createState() =>
      _ReferralAndRewardActionSheetState();
}

class _ReferralAndRewardActionSheetState
    extends State<ReferralAndRewardActionSheet> {
  final ReferralService _referralService = ReferralService();
  final _referralCodeController = TextEditingController();

  bool _isRewardProgram = false;

  bool _isSubmitting = false;
  bool _isDisabled = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    _referralCodeController.addListener(() {
      setState(() {
        _isDisabled = _referralCodeController.text.trim().isEmpty;
        _errorMsg = null;
      });
    });
  }

  void _closeSheet() {
    Navigator.of(context).pop();
  }

  Future<void> _handleSubmitReferral(String referralCode) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _referralService.submitReferralToBackend(referral: referralCode);

      setState(() {
        _isSubmitting = false;
        _isRewardProgram = true;
      });
    } catch (e) {
      print('Failed submitting referral code: $e');

      setState(() {
        _isSubmitting = false;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _handleOptIn() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _referralService.optInRewardProgram();

      setState(() {
        _isSubmitting = false;
      });

      _closeSheet();
    } catch (e) {
      print('Failed opting in reward program: $e');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Container(
        height: height * AppConstants.sendingSheetHeightFraction,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: _buildSheetContent(context),
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context) {
    if (_isRewardProgram) {
      return _buildRewardProgram(context);
    } else if (widget.referralCode != null) {
      return _buildPrefilledReferralForm(context, widget.referralCode!);
    } else {
      return _buildManualReferralForm(context);
    }
  }

  Widget _buildManualReferralForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _isSubmitting ? null : _closeSheet,
                child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Referral Code',
          style: context.themeText.mediumTitle?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.isTablet ? 36 : 28),
        Text(
          'Have you been referred by another user? Enter their 5 word code here:',
          style: context.themeText.smallParagraph?.copyWith(
            color: context.themeColors.inputLabel,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          controller: _referralCodeController,
          hintText: 'Referral Code',
          errorMsg: _errorMsg,
          trailing: InkWell(
            onTap: () async {
              final data = await Clipboard.getData('text/plain');
              if (data != null && data.text != null) {
                _referralCodeController.text = data.text!;
              }
            },
            child: SvgPicture.asset(
              'assets/paste_icon_1.svg',
              width: context.isTablet ? 24 : 18,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your referrer will get points when you join Quantus Network.',
          style: context.themeText.smallParagraph?.copyWith(
            color: context.themeColors.inputLabel.useOpacity(0.8),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: context.isTablet ? 465 : null,
          child: Button(
            label: 'Submit',
            isLoading: _isSubmitting,
            isDisabled: _isDisabled,
            variant: ButtonVariant.primary,
            onPressed: () {
              _handleSubmitReferral(_referralCodeController.text);
            },
          ),
        ),
        SizedBox(height: context.themeSize.bottomButtonSpacing),
      ],
    );
  }

  Widget _buildPrefilledReferralForm(
    BuildContext context,
    String referralCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _isSubmitting ? null : _closeSheet,
                child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'You have been referred by:',
          style: context.themeText.mediumTitle?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        CustomTextField(
          initialValue: widget.referralCode,
          errorMsg: _errorMsg,
          textStyle: context.themeText.paragraph?.copyWith(
            color: context.themeColors.checksum,
          ),
          disabled: true,
        ),
        const SizedBox(height: 24),
        Text(
          'Your referrer will get points when you join Quantus Network.',
          style: context.themeText.smallParagraph?.copyWith(
            color: context.themeColors.inputLabel.useOpacity(0.8),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: context.isTablet ? 465 : null,
          child: Button(
            label: 'Next',
            isLoading: _isSubmitting,
            variant: ButtonVariant.primary,
            onPressed: () {
              _handleSubmitReferral(referralCode);
            },
          ),
        ),
        SizedBox(height: context.themeSize.bottomButtonSpacing),
      ],
    );
  }

  Widget _buildRewardProgram(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _isSubmitting ? null : _closeSheet,
                child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/quantum_cat_magician.png',
              height: 80,
              width: 80,
            ),
            const SizedBox(width: 11),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Quantus Quests\n',
                    style: context.themeText.mediumTitle?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.themeColors.pink,
                    ),
                  ),
                  TextSpan(
                    text: 'Reward Program',
                    style: context.themeText.mediumTitle?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.isTablet ? 36 : 28),
        Text(
          'Register now and start earning points for referrals, mining, app activity, bounties, quests and more!',
          style: context.themeText.smallParagraph?.copyWith(
            color: context.themeColors.inputLabel,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Participants will be rewarded for their early support of Quantus Network and are eligible for valuable quests and competitions.',
          style: context.themeText.smallParagraph?.copyWith(
            color: context.themeColors.inputLabel,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: context.isTablet ? 465 : null,
          child: Button(
            label: "I'm In",
            isLoading: _isSubmitting,
            variant: ButtonVariant.primary,
            onPressed: _handleOptIn,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: context.isTablet ? 465 : null,
          child: Button(
            label: 'No thanks',
            isLoading: _isSubmitting,
            variant: ButtonVariant.glassOutline,
            onPressed: _closeSheet,
          ),
        ),
        SizedBox(height: context.themeSize.bottomButtonSpacing),
      ],
    );
  }
}

void showReferralAndRewardActionSheet(
  BuildContext context, {
  String? referralCode,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  const Color(0xFF312E6E).useOpacity(0.4),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.useOpacity(0.3),
              child: ReferralAndRewardActionSheet(referralCode: referralCode),
            ),
          ),
        ),
      ],
    ),
  );
}
