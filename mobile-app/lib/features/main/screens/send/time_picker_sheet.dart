import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class TimePickerSheet extends StatelessWidget {
  final int reversibleTimeDays;
  final int reversibleTimeHours;
  final int reversibleTimeMinutes;
  final Function(int) setReversibleTimeSeconds;
  final Function(int) saveReversibleTimeSetting;

  const TimePickerSheet({
    super.key,
    required this.reversibleTimeDays,
    required this.reversibleTimeHours,
    required this.reversibleTimeMinutes,
    required this.setReversibleTimeSeconds,
    required this.saveReversibleTimeSetting,
  });

  @override
  Widget build(BuildContext context) {
    var selectedDays = reversibleTimeDays;
    var selectedHours = reversibleTimeHours;
    var selectedMinutes = reversibleTimeMinutes;

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
                'Set Reverse Window',
                textAlign: TextAlign.center,
                style: context.themeText.smallTitle?.copyWith(
                  color: context.themeColors.checksum,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: context.themeSize.timePickerSubtitleWidth,
                child: Text(
                  'Your transaction is reversible during this time period',
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
                // Days
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Days',
                        style: context.themeText.largeTag?.copyWith(
                          color: context.themeColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: selectedDays,
                                ),
                                itemExtent: 40,
                                onSelectedItemChanged: (index) =>
                                    selectedDays = index,
                                children: List.generate(
                                  8,
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
                            const Text(
                              ':',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                              ),
                            ),
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
                      Text(
                        'Hours',
                        style: context.themeText.largeTag?.copyWith(
                          color: context.themeColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: selectedHours,
                                ),
                                itemExtent: 40,
                                onSelectedItemChanged: (index) =>
                                    selectedHours = index,
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
                            const Text(
                              ':',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Minutes
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Minutes',
                        style: context.themeText.largeTag?.copyWith(
                          color: context.themeColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: selectedMinutes,
                          ),
                          itemExtent: 40,
                          onSelectedItemChanged: (index) =>
                              selectedMinutes = index,
                          children: List.generate(
                            60,
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
                    final newTimeSeconds =
                        (selectedDays * 86400) +
                        (selectedHours * 3600) +
                        (selectedMinutes * 60);

                    setReversibleTimeSeconds(newTimeSeconds);
                    saveReversibleTimeSetting(newTimeSeconds);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}

void showTimePickerSheet(
  BuildContext context, {
  required int reversibleTimeDays,
  required int reversibleTimeHours,
  required int reversibleTimeMinutes,
  required Function(int) setReversibleTimeSeconds,
  required Function(int) saveReversibleTimeSetting,
}) {
  showAppModalBottomSheet(
    context: context,
    builder: (context) => TimePickerSheet(
      reversibleTimeDays: reversibleTimeDays,
      reversibleTimeHours: reversibleTimeHours,
      reversibleTimeMinutes: reversibleTimeMinutes,
      setReversibleTimeSeconds: setReversibleTimeSeconds,
      saveReversibleTimeSetting: saveReversibleTimeSetting,
    ),
  );
}
