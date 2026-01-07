import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';
import 'package:resonance_network_wallet/utils/validators.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateXScreen extends ConsumerStatefulWidget {
  const UpdateXScreen({super.key});

  @override
  ConsumerState<UpdateXScreen> createState() => _UpdateXScreenState();
}

class _UpdateXScreenState extends ConsumerState<UpdateXScreen> {
  final _taskmasterService = TaskmasterService();
  final _handleController = TextEditingController();
  final _postUrlController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _handleController.addListener(_onInputChanged);
    _postUrlController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _handleController.removeListener(_onInputChanged);
    _postUrlController.removeListener(_onInputChanged);
    _handleController.dispose();
    _postUrlController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      if (_errorMsg != null) _errorMsg = null;
    });
  }

  Future<void> _launchUpdateBio() async {
    final Uri url = Uri.parse('https://x.com/${_handleController.text.trim()}');
    if (!await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
      if (mounted) {
        context.showErrorSnackbar(title: 'Error', message: 'Could not launch X app');
      }
    }
  }

  Future<void> _launchPostVerification() async {
    const text = "I'm joining as a quantus raider.";
    final Uri url = Uri.parse('https://x.com/intent/tweet?text=${Uri.encodeComponent(text)}');

    if (!await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
      if (mounted) {
        context.showErrorSnackbar(title: 'Error', message: 'Could not launch X app');
      }
    }
  }

  Future<void> _handleVerify() async {
    final handle = _handleController.text.trim();
    final postUrl = _postUrlController.text.trim();

    if (handle.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter your X handle';
      });
      return;
    }

    if (postUrl.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter your post URL';
      });
      return;
    }

    if (!Validators.isValidXStatusUrl(postUrl)) {
      setState(() {
        _errorMsg = 'Invalid X post link.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      await _taskmasterService.associateXHandle(handle);

      if (mounted) {
        context.showSuccessSnackbar(title: 'Success', message: 'X account associated!');
      }

      ref.invalidate(accountAssociationsProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Failed verifying X account: $e');
      setState(() {
        _errorMsg = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handleController.text.trim();
    final postUrl = _postUrlController.text.trim();

    final isHandleEmpty = handle.isEmpty;
    final isPostUrlEmpty = postUrl.isEmpty;
    final isPostUrlValid = Validators.isValidXStatusUrl(postUrl);

    String? postUrlError;
    bool isPostHandleMatching = true;

    if (!isPostUrlEmpty) {
      if (!isPostUrlValid) {
        postUrlError = 'Invalid X post link.';
      } else {
        final extractedHandle = Validators.extractHandleFromXStatusUrl(postUrl);
        final normalizedInputHandle = handle.startsWith('@') ? handle.substring(1) : handle;

        if (extractedHandle?.toLowerCase() != normalizedInputHandle.toLowerCase()) {
          postUrlError = 'Invalid X post link.';
          isPostHandleMatching = false;
        }
      }
    }

    final isVerifyDisabled = isHandleEmpty || !isPostUrlValid || !isPostHandleMatching || _isSubmitting;

    return ScaffoldBase(
      decorations: [
        Positioned(right: -50, top: context.containerHalfHeight, child: const Sphere(variant: 2, size: 194)),
      ],
      appBar: WalletAppBar(title: 'Update X Account'),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    '1. Enter your X handle',
                    style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.inputLabel),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _handleController,
                    hintText: 'username',
                    onChanged: (_) {
                      if (_errorMsg != null) {
                        setState(() {
                          _errorMsg = null;
                        });
                      }
                    },
                    trailing: InkWell(
                      onTap: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data != null && data.text != null) {
                          _handleController.text = data.text!;
                        }
                      },
                      child: SvgPicture.asset('assets/paste_icon_1.svg', width: context.isTablet ? 24 : 18),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '2. Update your bio to include @QuantusNetwork',
                    style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.inputLabel),
                  ),
                  const SizedBox(height: 8),
                  Button(
                    label: 'Edit Bio',
                    variant: ButtonVariant.neutral,
                    onPressed: _launchUpdateBio,
                    isDisabled: isHandleEmpty,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '3. Post your participation on X',
                    style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.inputLabel),
                  ),
                  const SizedBox(height: 8),
                  Button(
                    label: 'Post Participation',
                    variant: ButtonVariant.neutral,
                    onPressed: _launchPostVerification,
                    isDisabled: isHandleEmpty,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '4. Paste your post link',
                    style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.inputLabel),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _postUrlController,
                    hintText: 'https://x.com/...',
                    errorMsg: postUrlError,
                    onChanged: (_) {
                      if (_errorMsg != null) {
                        setState(() {
                          _errorMsg = null;
                        });
                      }
                    },
                    trailing: InkWell(
                      onTap: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data != null && data.text != null) {
                          _postUrlController.text = data.text!;
                        }
                      },
                      child: SvgPicture.asset('assets/paste_icon_1.svg', width: context.isTablet ? 24 : 18),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
              child: Center(
                child: Text(
                  _errorMsg!,
                  style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          SizedBox(
            width: context.isTablet ? 465 : double.infinity,
            child: Button(
              label: 'Verify',
              isLoading: _isSubmitting,
              variant: ButtonVariant.primary,
              isDisabled: isVerifyDisabled,
              onPressed: _handleVerify,
            ),
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}
