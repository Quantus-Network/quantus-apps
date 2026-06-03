import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/address_details_card.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/share_account_button.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';

class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  final _checksumService = HumanReadableChecksumService();
  String? _checksum;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _checksumService.getHumanReadableName(widget.accountId);
    if (mounted) {
      setState(() {
        _checksum = c;
        _isLoading = false;
      });
    }
  }

  void _share() {
    if (_isLoading || _checksum == null) return;

    shareAccountDetails(context, widget.accountId, checksum: _checksum!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.accountDetailsTitle),
      mainContent: AddressDetailsCard(accountId: widget.accountId, checksum: _checksum),
      bottomContent: ScaffoldBaseBottomContent(
        child: ShareAccountButton(onTap: _share, isDisabled: _isLoading),
      ),
    );
  }
}
