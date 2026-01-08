import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/remove_association_confirmation_sheet.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/update_x_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/raider_quest_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';

class AccountAssociationsScreen extends ConsumerStatefulWidget {
  const AccountAssociationsScreen({super.key});

  @override
  ConsumerState<AccountAssociationsScreen> createState() => _AccountAssociationsScreenState();
}

class _AccountAssociationsScreenState extends ConsumerState<AccountAssociationsScreen> with WidgetsBindingObserver {
  final TaskmasterService _taskmasterService = TaskmasterService();

  final _ethAddress = TextEditingController();
  String? _ethAddressError;
  bool _isEditingEthAddress = false;
  bool _isSubmittingEthAddress = false;

  void _saveEthAddress() async {
    final associations = ref.watch(accountAssociationsProvider).value;

    try {
      setState(() {
        _isSubmittingEthAddress = true;
      });

      final newEthAddress = _ethAddress.text.trim();

      if (associations?.ethAddress != null) {
        await _taskmasterService.updateAssociatedEthAddress(newEthAddress);
      } else {
        await _taskmasterService.associateEthAddress(newEthAddress);
      }

      if (mounted) {
        context.showSuccessSnackbar(
          title: 'Saved successfully',
          message: 'Your ETH address is successfully associated',
        );
      }

      ref.invalidate(accountAssociationsProvider);

      setState(() {
        _isEditingEthAddress = false;
        _ethAddress.text = '';
      });
    } catch (e) {
      print('Failed associating ETH address: $e');

      setState(() {
        _ethAddressError = e.toString();
      });
    } finally {
      setState(() {
        _isSubmittingEthAddress = false;
      });
    }
  }

  Future<void> _removeEthAddress() async {
    await _taskmasterService.dissociateEthAddress();
    ref.invalidate(accountAssociationsProvider);
  }

  void _navigateToUpdateXScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateXScreen()));
  }

  Future<void> _removeXAccount() async {
    await _taskmasterService.dissociateXAccount();
    ref.invalidate(accountAssociationsProvider);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;

      case AppLifecycleState.resumed:
        ref.invalidate(accountAssociationsProvider);
        ref.invalidate(raiderSubmissionsProvider);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(accountAssociationsProvider);

    return ScaffoldBase(
      decorations: [
        Positioned(right: -50, top: context.containerHalfHeight, child: const Sphere(variant: 2, size: 194)),
      ],
      appBar: WalletAppBar(title: 'Account Associations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEthAssociationSection(associationsAsync),
          const SizedBox(height: 32),
          _buildXAssociationSection(associationsAsync),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: ShapeDecoration(
            color: context.themeColors.settingCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildEthAssociationSection(AsyncValue<AccountAssociations> associationsAsync) {
    final associatedEthAddress = associationsAsync.value?.ethAddress;
    final hasEthAddress = associatedEthAddress != null;
    final isLoading = associationsAsync.isLoading;

    String getDisplayText() {
      if (!hasEthAddress) return "You haven't linked your ETH";

      return context.isTablet
          ? associatedEthAddress
          : AddressFormattingService.splitIntoChunks(associatedEthAddress, chunkSize: 3).join(' ');
    }

    final inputWidget = CustomTextField(
      controller: _ethAddress,
      textStyle: context.themeText.smallParagraph,
      errorMsg: _ethAddressError,
      onChanged: (_) {
        if (_ethAddressError != null) {
          setState(() {
            _ethAddressError = null;
          });
        }
      },
    );

    final displayWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: context.isTablet ? 550 : 251,
          child: isLoading
              ? const Skeleton(width: 40, height: 16)
              : Text(getDisplayText(), style: context.themeText.smallParagraph),
        ),
        if (hasEthAddress) const CopyIcon(),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ETH Address'),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            if (hasEthAddress) {
              ClipboardExtensions.copyTextWithSnackbar(context, associatedEthAddress);
            }
          },
          child: _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: _isEditingEthAddress ? inputWidget : displayWidget,
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        Row(
          spacing: 12.0,
          children: [
            if (_isEditingEthAddress)
              SizedBox(
                width: 100.0,
                child: Button(
                  variant: ButtonVariant.neutral,
                  label: 'Save',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isLoading: _isSubmittingEthAddress,
                  onPressed: _saveEthAddress,
                ),
              )
            else
              SizedBox(
                width: 100.0,
                child: Button(
                  variant: ButtonVariant.neutral,
                  label: 'Update',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onPressed: () {
                    setState(() {
                      _isEditingEthAddress = true;
                    });
                  },
                  isDisabled: isLoading,
                ),
              ),

            if (_isEditingEthAddress)
              SizedBox(
                width: 100.0,
                child: Button(
                  variant: ButtonVariant.glass,
                  label: 'Cancel',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDisabled: _isSubmittingEthAddress,
                  onPressed: () {
                    setState(() {
                      _isEditingEthAddress = false;
                    });
                  },
                ),
              ),

            if (!_isEditingEthAddress && hasEthAddress)
              SizedBox(
                width: 100.0,
                child: Button(
                  variant: ButtonVariant.danger,
                  label: 'Remove',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onPressed: () {
                    showRemoveAssociationConfirmationSheet(context, _removeEthAddress);
                  },
                  isDisabled: isLoading,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildXAssociationSection(AsyncValue<AccountAssociations> associationsAsync) {
    final associatedXUsername = associationsAsync.value?.xUsername;
    final hasXUsername = associatedXUsername != null;
    final isLoading = associationsAsync.isLoading;

    String getDisplayText() {
      if (associatedXUsername == null) return "You haven't linked your X";

      return associatedXUsername;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('X Account'),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            if (hasXUsername) {
              ClipboardExtensions.copyTextWithSnackbar(
                context,
                associatedXUsername,
                message: 'Username copied to clipboard',
              );
            }
          },
          child: _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: context.isTablet ? 550 : 251,
                    child: isLoading
                        ? const Skeleton(width: 40, height: 16)
                        : Text(getDisplayText(), style: context.themeText.smallParagraph),
                  ),
                  if (hasXUsername) const CopyIcon(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        Row(
          spacing: 12.0,
          children: [
            if (hasXUsername)
              SizedBox(
                width: 100.0,
                child: Button(
                  variant: ButtonVariant.danger,
                  label: 'Remove',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onPressed: () {
                    showRemoveAssociationConfirmationSheet(context, _removeXAccount);
                  },
                  isDisabled: isLoading,
                ),
              )
            else
              SizedBox(
                width: 100.0,
                child: Button(
                  variant: ButtonVariant.neutral,
                  label: 'Update',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onPressed: _navigateToUpdateXScreen,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
