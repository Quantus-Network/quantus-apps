import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Surface panel listing the radios the platform still reports (Figma Offline
/// gate): WI-FI, CELLULAR and BLUETOOTH rows, ON in ember or OFF in sage.
///
/// BLUETOOTH is connectivity_plus's Bluetooth network result, not the radio
/// state: reading the radio itself needs a Bluetooth permission.
class RadioStatusPanel extends StatelessWidget {
  final List<ConnectivityResult> results;

  const RadioStatusPanel({super.key, required this.results});

  static const _rows = [
    ('WI-FI', ConnectivityResult.wifi),
    ('CELLULAR', ConnectivityResult.mobile),
    ('BLUETOOTH', ConnectivityResult.bluetooth),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: [
          for (final (i, (label, result)) in _rows.indexed)
            _RadioRow(label: label, on: results.contains(result), divided: i > 0),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool on;
  final bool divided;

  const _RadioRow({required this.label, required this.on, required this.divided});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: colors.borderHairline)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted2),
            ),
          ),
          Text(
            on ? 'ON' : 'OFF',
            style: text.dataAddress.copyWith(color: on ? colors.semanticEmber : colors.semanticSage),
          ),
        ],
      ),
    );
  }
}
