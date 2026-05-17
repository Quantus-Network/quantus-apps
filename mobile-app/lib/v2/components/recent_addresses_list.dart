import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Recents list backed by [recentAddressesServiceProvider]. Filters out any
/// addresses in [excludeAddresses] (typically the user's own active account).
/// Renders as slivers so it can live inside the screen's main CustomScrollView.
class RecentAddressesSlivers extends ConsumerStatefulWidget {
  final Set<String> excludeAddresses;
  final ValueChanged<String> onTap;
  final String title;

  const RecentAddressesSlivers({
    super.key,
    required this.excludeAddresses,
    required this.onTap,
    this.title = 'Recents',
  });

  @override
  ConsumerState<RecentAddressesSlivers> createState() => _RecentAddressesSliversState();
}

class _RecentAddressesSliversState extends ConsumerState<RecentAddressesSlivers> {
  final Map<String, String> _checksums = {};
  List<String> _recents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recentAddressesService = ref.read(recentAddressesServiceProvider);
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    try {
      final all = await recentAddressesService.getAddresses();
      final addresses = all.where((a) => !widget.excludeAddresses.contains(a)).toList();
      if (!mounted) return;
      setState(() {
        _recents = addresses;
        _loading = false;
      });
      for (final addr in addresses) {
        checksumService.getHumanReadableName(addr).then((name) {
          if (mounted) setState(() => _checksums[addr] = name);
        });
      }
    } catch (e) {
      debugPrint('RecentAddressesSlivers load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverFillRemaining(hasScrollBody: false, child: Center(child: Loader()));
    }
    if (_recents.isEmpty) {
      return const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink());
    }

    final colors = context.colors;
    final text = context.themeText;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Text(widget.title, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final isFirst = i == 0;
            final isLast = i == _recents.length - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFirst) const SizedBox(height: 14),
                _recentRow(_recents[i], colors),
                if (!isLast) ...[const SizedBox(height: 14), Divider(height: 1, color: colors.txItemSeparator)],
              ],
            );
          }, childCount: _recents.length),
        ),
      ],
    );
  }

  Widget _recentRow(String address, AppColorsV2 colors) {
    final checksum = _checksums[address];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTap(address),
        borderRadius: BorderRadius.circular(8),
        child: checksum != null
            ? AddressCheckphraseWithInitial(recipientChecksum: checksum, recipientAddress: address)
            : const Skeleton(height: 36),
      ),
    );
  }
}
