import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/paste_icon.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/raider_quest_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/utils/validators.dart';

class RaidSubmissionActionSheet extends ConsumerStatefulWidget {
  const RaidSubmissionActionSheet({super.key});

  @override
  ConsumerState<RaidSubmissionActionSheet> createState() => _RaidSubmissionActionSheetState();
}

class _RaidSubmissionActionSheetState extends ConsumerState<RaidSubmissionActionSheet> {
  final _taskmasterService = TaskmasterService();

  final _targetTweetController = TextEditingController();
  final _replyTweetController = TextEditingController();

  bool _isSubmitting = false;
  bool _isDisabled = true;

  String? _replyErrorMsg;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    _targetTweetController.addListener(_checkFormValidity);
    _replyTweetController.addListener(_checkFormValidity);
  }

  void _checkFormValidity() {
    String replyInput = _replyTweetController.text.trim();

    bool replyTweetIsValid = Validators.isValidXStatusUrl(replyInput);

    String errMsg = 'Invalid X status link.';

    setState(() {
      _isDisabled = !replyTweetIsValid;
      _errorMsg = null;
      _replyErrorMsg = replyTweetIsValid ? null : errMsg;
    });
  }

  void _closeSheet() {
    Navigator.of(context).pop();
  }

  Future<void> _handleSubmit(String replyLink) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _taskmasterService.addRaidSubmission(replyLink);
      if (mounted) {
        context.showSuccessToaster(message: 'Success adding raid submission!');
      }
      ref.invalidate(raiderSubmissionsProvider);
      _closeSheet();
    } catch (e) {
      print('Failed adding raid submission: $e');

      String errorMessage = e.toString();
      if (errorMessage.contains('409') || errorMessage.contains('conflicting with existing record')) {
        errorMessage = 'You already submitted this link';
      }

      setState(() {
        _isSubmitting = false;
        _errorMsg = errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    final effectiveHeight = height * 0.76;
    final effectiveRadius = 5.0;
    final effectivePadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    return SafeArea(
      child: Container(
        height: effectiveHeight,
        padding: effectivePadding,
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(effectiveRadius)),
        ),
        child: _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
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
        Text('Raid Submission', style: context.themeText.mediumTitle?.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: context.isTablet ? 32 : 24),
        Text(
          'Have you conducted a raid on a target? Enter your raid detail here:',
          style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.inputLabel),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _replyTweetController,
          labelText: 'Reply Tweet Link',
          fillColor: context.themeColors.background,
          trailing: InkWell(
            onTap: () async {
              final data = await Clipboard.getData('text/plain');
              if (data != null && data.text != null) {
                _replyTweetController.text = data.text!;
              }
            },
            child: const PasteIcon(),
          ),
          errorMsg: _replyErrorMsg,
        ),
        const SizedBox(height: 24),
        const Spacer(),
        if (_errorMsg != null)
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMsg!, style: context.themeText.detail?.copyWith(color: context.themeColors.textError)),
                const SizedBox(height: 4),
              ],
            ),
          ),
        SizedBox(
          width: context.isTablet ? 465 : null,
          child: Button(
            label: 'Submit',
            isLoading: _isSubmitting,
            isDisabled: _isDisabled,
            variant: ButtonVariant.primary,
            onPressed: () {
              _handleSubmit(_replyTweetController.text);
            },
          ),
        ),

        SizedBox(height: context.themeSize.bottomButtonSpacing),
      ],
    );
  }
}

void showRaidSubmissionActionSheet(
  BuildContext context, {
  String? referralCode,
  bool? directlyShowRewardProgram,
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
                colors: [Colors.black, const Color(0xFF312E6E).useOpacity(0.4), Colors.black],
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
            child: Container(color: Colors.black.useOpacity(0.3), child: const RaidSubmissionActionSheet()),
          ),
        ),
      ],
    ),
  );
}
