import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class HighSecurityDetailsScreen extends ConsumerWidget {
  final Account account;
  const HighSecurityDetailsScreen({super.key, required this.account});

  // Shared style accessors
  static TextStyle text16(BuildContext context) => TextStyle(
    color: context.themeColors.textPrimary,
    fontSize: 16,
    fontFamily: 'Fira Code',
    fontWeight: FontWeight.w400,
  );

  static TextStyle statusTitle(BuildContext context) => TextStyle(
    color: context.themeColors.textSecondary,
    fontSize: 16,
    fontFamily: 'Fira Code',
    fontWeight: FontWeight.w400,
  );

  static TextStyle statusSubtitle(BuildContext context) => TextStyle(
    color: context.themeColors.textSecondary,
    fontSize: 12,
    fontFamily: 'Fira Code',
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(highSecurityConfigProvider(account));

    return ScaffoldBase(
      appBar: WalletAppBar.simpleWithBackButton(title: 'Account Settings'),
      child: configAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.themeColors.circularLoader),
              const SizedBox(height: 12),
              Text('Loading...', style: context.themeText.smallParagraph),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Failed to load High Security settings: $e', style: context.themeText.smallParagraph),
          ),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('High Security is not enabled for this account.', style: context.themeText.smallParagraph),
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 27, right: 27, top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const _StatusCard(),
                  const SizedBox(height: 20),
                  _GuardianAccountSection(guardianAccountId: data.guardianAccountId),
                  const SizedBox(height: 20),
                  _SafeguardWindowSection(safeguardWindow: data.safeguardWindow),
                  // const SizedBox(height: 20),
                  // const _RemindersSection(reminders: reminders),
                  SizedBox(height: context.themeSize.bottomButtonSpacing),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String shortAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 7)}...${address.substring(address.length - 5)}';
  }
}

class _GuardianAccountSection extends StatelessWidget {
  final String guardianAccountId;
  const _GuardianAccountSection({required this.guardianAccountId});

  @override
  Widget build(BuildContext context) {
    final style = HighSecurityDetailsScreen.text16(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Guardian Account', style: style),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 321),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8, left: 8, right: 18, bottom: 8),
            decoration: ShapeDecoration(
              color: const Color(0xFF3D3C44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(HighSecurityDetailsScreen.shortAddress(guardianAccountId), style: style),
          ),
        ),
      ],
    );
  }
}

class _SafeguardWindowSection extends StatelessWidget {
  final Duration safeguardWindow;
  const _SafeguardWindowSection({required this.safeguardWindow});

  @override
  Widget build(BuildContext context) {
    final formatted = _formatDuration(safeguardWindow);
    final style = HighSecurityDetailsScreen.text16(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Safeguard Window', style: style),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 321),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: ShapeDecoration(
              color: const Color(0xFF3D3C44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(formatted, style: style),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final totalHours = d.inHours;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    if (days > 0) return '$days days, $hours hrs';
    return '$hours hrs';
  }
}

// TO-DO: add a reminder service - implement this
// ignore: unused_element
class _RemindersSection extends StatelessWidget {
  final List<String> reminders;
  const _RemindersSection({required this.reminders});

  @override
  Widget build(BuildContext context) {
    final style = HighSecurityDetailsScreen.text16(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminders', style: style),
        const SizedBox(height: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final reminder in reminders) ...[_ReminderRow(label: reminder), const SizedBox(height: 12)],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const XIcon(),
            const SizedBox(width: 17),
            Text('Add Reminder', style: style),
          ],
        ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final String label;
  const _ReminderRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final width = context.isTablet ? 420.0 : double.infinity;
    final style = HighSecurityDetailsScreen.text16(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 321),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: ShapeDecoration(
          color: const Color(0xFF3D3C44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            const _ChevronIcon(),
          ],
        ),
      ),
    );
  }
}

class _ChevronIcon extends StatelessWidget {
  const _ChevronIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12.84,
      height: 12.84,
      child: Stack(
        children: [
          Positioned(
            left: 10.14,
            top: 0,
            child: Transform.rotate(
              angle: 0.79,
              child: Container(
                width: 3.81,
                height: 2,
                decoration: ShapeDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.50)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class XIcon extends StatelessWidget {
  const XIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 12,
              height: 2,
              decoration: ShapeDecoration(
                color: context.themeColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.50)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 2,
              height: 12,
              decoration: ShapeDecoration(
                color: context.themeColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.50)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, left: 12, right: 18, bottom: 12),
      decoration: ShapeDecoration(
        color: const Color(0xFF4CEDE7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 25,
                child: Stack(
                  children: [
                    Positioned(left: 5, top: 16, child: _StatusDot()),
                    Positioned(left: 9, top: 16, child: _StatusDot()),
                    Positioned(left: 13, top: 16, child: _StatusDot()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('High Security', style: HighSecurityDetailsScreen.statusTitle(context)),
                  const SizedBox(height: 4),
                  Text('ON', style: HighSecurityDetailsScreen.statusSubtitle(context)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 2,
      height: 2,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: Color(0xFF0B0F14), shape: OvalBorder()),
      ),
    );
  }
}
