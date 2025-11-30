import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';

class AccountAssociationsScreen extends ConsumerStatefulWidget {
  const AccountAssociationsScreen({super.key});

  @override
  ConsumerState<AccountAssociationsScreen> createState() => _AccountAssociationsScreenState();
}

class _AccountAssociationsScreenState extends ConsumerState<AccountAssociationsScreen> {
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
          const SizedBox(height: 20),
          _buildEthAssociationSection(associationsAsync),
          const SizedBox(height: 20),
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
    final isLoading = associationsAsync.isLoading;

    String getDisplayText() {
      if (associatedEthAddress == null) return "You haven't linked your ETH";

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

    final displayWidget = SizedBox(
      width: context.isTablet ? 550 : 251,
      child: isLoading
          ? const Skeleton(width: 40, height: 16)
          : Text(getDisplayText(), style: context.themeText.smallParagraph),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ETH Address'),
        const SizedBox(height: 4),
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: _isEditingEthAddress ? inputWidget : displayWidget,
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
          ],
        ),
      ],
    );
  }
}
