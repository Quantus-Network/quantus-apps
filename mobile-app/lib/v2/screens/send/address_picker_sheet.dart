import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AddressPickerSheet extends StatefulWidget {
  const AddressPickerSheet({super.key});

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  final _searchController = TextEditingController();
  final _checksumService = HumanReadableChecksumService();
  List<String> _addresses = [];
  List<String> _filtered = [];
  final Map<String, String> _checksums = {};

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final allAddresses = await RecentAddressesService().getAddresses();
    final active = await SettingsService().getActiveAccount();
    final currentId = active?.account.accountId;
    final addresses = allAddresses.where((a) => a != currentId).toList();
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _filtered = addresses;
    });
    for (final addr in addresses) {
      _checksumService.getHumanReadableName(addr).then((name) {
        if (mounted) setState(() => _checksums[addr] = name);
      });
    }
  }

  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _addresses
          : _addresses.where((a) {
              final checksum = _checksums[a]?.toLowerCase() ?? '';
              return a.toLowerCase().contains(query) || checksum.contains(query);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF3D3D3D)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 530,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppBackButton(),
                  Text('Send To', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: colors.textPrimary, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colors.textTertiary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Search',
                          hintStyle: text.smallParagraph?.copyWith(color: colors.textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recents',
                  style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text('No recent addresses', style: text.detail?.copyWith(color: colors.textTertiary)),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 24),
                        itemBuilder: (context, i) => _addressItem(_filtered[i], colors, text),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressItem(String address, AppColorsV2 colors, AppTextTheme text) {
    final checksum = _checksums[address];
    return GestureDetector(
      onTap: () => Navigator.pop(context, address),
      child: Row(
        children: [
          AccountGradientImage(accountId: address, width: 40.0, height: 40.0),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (checksum != null) Text(checksum, style: text.smallParagraph?.copyWith(color: colors.accentPink)),
                const SizedBox(height: 4),
                Text(
                  AddressFormattingService.formatAddress(address),
                  style: text.smallParagraph?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showAddressPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
    builder: (_) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: const AddressPickerSheet()),
  );
}
