import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class SafeguardWindowPickerSheet extends StatelessWidget {
  final int safeguardTimeMonths;
  final int safeguardTimeDays;
  final int safeguardTimeHours;
  final Function(int) setSafeguardTimeSeconds;

  const SafeguardWindowPickerSheet({
    super.key,
    required this.safeguardTimeMonths,
    required this.safeguardTimeDays,
    required this.safeguardTimeHours,
    required this.setSafeguardTimeSeconds,
  });

  @override
  Widget build(BuildContext context) {
    var selectedMonths = safeguardTimeMonths;
    var selectedDays = safeguardTimeDays;
    var selectedHours = safeguardTimeHours;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 60),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Column(
            children: [
              SvgPicture.asset('assets/hourglass.svg', width: 29),
              const SizedBox(height: 16),
              Text(
                'Set Safeguard Window',
                textAlign: TextAlign.center,
                style: context.themeText.smallTitle?.copyWith(color: context.themeColors.checksum),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: context.themeSize.timePickerSubtitleWidth,
                child: Text(
                  'The Guardian can intercept a transaction during this period',
                  textAlign: TextAlign.center,
                  style: context.themeText.detail,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Time pickers
          Expanded(
            child: Row(
              children: [
                // Months
                Expanded(
                  child: Column(
                    children: [
                      Text('Months', style: context.themeText.largeTag?.copyWith(color: context.themeColors.textMuted)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(initialItem: selectedMonths),
                                itemExtent: 40,
                                onSelectedItemChanged: (index) => selectedMonths = index,
                                children: List.generate(
                                  13,
                                  (index) => Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontFamily: 'Fira Code',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Text(':', style: TextStyle(color: Colors.white, fontSize: 28)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Days
                Expanded(
                  child: Column(
                    children: [
                      Text('Days', style: context.themeText.largeTag?.copyWith(color: context.themeColors.textMuted)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(initialItem: selectedDays),
                                itemExtent: 40,
                                onSelectedItemChanged: (index) => selectedDays = index,
                                children: List.generate(
                                  30,
                                  (index) => Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontFamily: 'Fira Code',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Text(':', style: TextStyle(color: Colors.white, fontSize: 28)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Hours
                Expanded(
                  child: Column(
                    children: [
                      Text('Hours', style: context.themeText.largeTag?.copyWith(color: context.themeColors.textMuted)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: selectedHours),
                          itemExtent: 40,
                          onSelectedItemChanged: (index) => selectedHours = index,
                          children: List.generate(
                            24,
                            (index) => Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: Button(
                  variant: ButtonVariant.neutral,
                  label: 'Cancel',
                  textStyle: context.themeText.paragraph?.copyWith(
                    color: context.themeColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Button(
                  variant: ButtonVariant.success,
                  label: 'Set',
                  textStyle: context.themeText.paragraph?.copyWith(
                    color: context.themeColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  onPressed: () {
                    final int secondsInAMonth = 86400 * 30; // 86400 seconds/day * 30 days/month
                    final newTimeSeconds =
                        (selectedMonths * secondsInAMonth) + (selectedDays * 86400) + (selectedHours * 3600);

                    setSafeguardTimeSeconds(newTimeSeconds);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 35),
        ],
      ),
    );
  }
}

void showSafeguardWindowPickerSheet(
  BuildContext context, {
  required int safeguardTimeMonths,
  required int safeguardTimeDays,
  required int safeguardTimeHours,

  required Function(int) setSafeguardTimeSeconds,
}) {
  showAppModalBottomSheet(
    context: context,
    builder: (context) => SafeguardWindowPickerSheet(
      safeguardTimeMonths: safeguardTimeMonths,
      safeguardTimeDays: safeguardTimeDays,
      safeguardTimeHours: safeguardTimeHours,

      setSafeguardTimeSeconds: setSafeguardTimeSeconds,
    ),
  );
}
