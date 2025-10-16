import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/quests_promo_video.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class ReferralAndRewardActionSheet extends StatefulWidget {
  final String? referralCode;
  final bool? directlyShowRewardProgram;
  final int? currentNavbarIndex;
  final bool showRewardProgram;

  const ReferralAndRewardActionSheet({
    super.key,
    this.referralCode,
    this.directlyShowRewardProgram,
    this.currentNavbarIndex,
    this.showRewardProgram = true,
  });

  @override
  State<ReferralAndRewardActionSheet> createState() =>
      _ReferralAndRewardActionSheetState();
}

class _ReferralAndRewardActionSheetState
    extends State<ReferralAndRewardActionSheet> {
  final SettingsService _settingsService = SettingsService();
  final ReferralService _referralService = ReferralService();
  final _referralCodeController = TextEditingController();

  String? _checksum;
  bool _isRewardProgram = false;
  bool _isLastPromo = false;
  bool _isSubmitting = false;
  bool _isDisabled = true;
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    setState(() {
      _isRewardProgram = widget.directlyShowRewardProgram ?? false;
    });

    _loadReferralData();

    _referralCodeController.addListener(() {
      setState(() {
        _isDisabled = _referralCodeController.text.trim().isEmpty;
        _errorMsg = null;
      });
    });
  }

  void _setIsFinalVideo(bool value) {
    if (value) _settingsService.setQuestsPromoWatched();

    setState(() {
      _isLastPromo = value;
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
      final isRewardProgramParticipant = await _referralService
          .getRewardProgramParticiation();
      await _referralService.submitReferralToBackend(referral: referralCode);

      if (isRewardProgramParticipant) {
        _closeSheet();
      } else {
        setState(() {
          _isSubmitting = false;
          _isRewardProgram = true;
        });
      }
    } catch (e) {
      print('Failed submitting referral code: $e');

      setState(() {
        _isSubmitting = false;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _handleOptIn(BuildContext context) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _referralService.optInRewardProgram();

      setState(() {
        _isSubmitting = false;
      });

      _closeSheet();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'navbar'),
            builder: (context) =>
                Navbar(initialIndex: widget.currentNavbarIndex ?? 3),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('Failed opting in reward program: $e');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _loadReferralData() async {
    final referraldata = await _referralService.getReferralData();

    if (referraldata != null) {
      _checksum = await HumanReadableChecksumService().getHumanReadableName(
        referraldata.referrerAddress,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleSkipReferral() async {
    final isRewardProgramParticipant = await _referralService
        .getRewardProgramParticiation();

    if (isRewardProgramParticipant || !widget.showRewardProgram) {
      _closeSheet();
    } else {
      setState(() {
        _isRewardProgram = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final effectiveHeight = _isRewardProgram
        ? height
        : height * AppConstants.sendingSheetHeightFraction;

    final effectiveRadius = _isRewardProgram ? 0.0 : 5.0;
    final effectivePadding = _isRewardProgram
        ? null
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    return SafeArea(
      child: Container(
        height: effectiveHeight,
        padding: effectivePadding,
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(effectiveRadius),
          ),
        ),
        child: _buildSheetContent(context),
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_isRewardProgram && widget.showRewardProgram) {
      return _buildRewardProgram(context);
    } else if (_checksum != null) {
      print(_checksum);
      return _buildReferralSubmittedInfo(context, _checksum!);
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
          fillColor: context.themeColors.background,
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
        const SizedBox(height: 24),
        SizedBox(
          width: context.isTablet ? 465 : null,
          child: Button(
            label: 'Skip',
            isLoading: _isSubmitting,
            variant: ButtonVariant.glassOutline,
            onPressed: _handleSkipReferral,
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
          initialValue: referralCode,
          fillColor: context.themeColors.background,
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

  Widget _buildReferralSubmittedInfo(
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
          'Your submitted referral code:',
          style: context.themeText.mediumTitle?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        CustomTextField(
          initialValue: referralCode,
          fillColor: context.themeColors.background,
          errorMsg: _errorMsg,
          textStyle: context.themeText.paragraph?.copyWith(
            color: context.themeColors.yellow,
          ),
          disabled: true,
        ),
        const SizedBox(height: 24),
        Text(
          'Your referrer and you get points because you submitted the referral code.',
          style: context.themeText.smallParagraph?.copyWith(
            color: context.themeColors.inputLabel.useOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardProgram(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 90),
            QuestsPromoVideo(
              isSubmitting: _isSubmitting,
              closeSheet: _closeSheet,
              setIsFinalVideo: _setIsFinalVideo,
              startFromBeginning: widget.directlyShowRewardProgram ?? false,
            ),
          ],
        ),
        if (_isLastPromo)
          Positioned(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: context.isTablet ? 465 : null,
                    child: Button(
                      label: "I'm In",
                      isLoading: _isSubmitting,
                      variant: ButtonVariant.primary,
                      onPressed: () {
                        _handleOptIn(context);
                      },
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
              ),
            ),
          ),
      ],
    );
  }
}

void showReferralAndRewardActionSheet(
  BuildContext context, {
  String? referralCode,
  bool? directlyShowRewardProgram,
  int? currentNavbarIndex,
  bool showRewardProgram = true,
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
              child: ReferralAndRewardActionSheet(
                referralCode: referralCode,
                directlyShowRewardProgram: directlyShowRewardProgram,
                currentNavbarIndex: currentNavbarIndex,
                showRewardProgram: showRewardProgram,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
