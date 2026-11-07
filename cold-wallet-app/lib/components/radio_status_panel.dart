import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Surface panel listing what the platform reports for each transport (Figma
/// Offline gate): WI-FI, CELLULAR and BLUETOOTH rows, CONNECTED in ember or
/// NOT CONNECTED in sage.
///
/// connectivity_plus reports active network paths, not whether a radio is
/// powered: a transport can be on without a connection. It never reports
/// Bluetooth on iOS, so that row says NOT REPORTED there. A path over anything
/// else (VPN, Ethernet, satellite, unknown) gets a fourth row, since it keeps
/// the gate up while the three radio rows all read NOT CONNECTED.
class RadioStatusPanel extends StatelessWidget {
  final List<ConnectivityResult> results;

  const RadioStatusPanel({super.key, required this.results});

  static const _rows = [
    ('WI-FI', ConnectivityResult.wifi),
    ('CELLULAR', ConnectivityResult.mobile),
    ('BLUETOOTH', ConnectivityResult.bluetooth),
  ];

  static bool _reported(ConnectivityResult result) =>
      result != ConnectivityResult.bluetooth || defaultTargetPlatform != TargetPlatform.iOS;

  static String _otherName(ConnectivityResult result) =>
      result == ConnectivityResult.other ? 'UNKNOWN' : result.name.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radios = _rows.map((row) => row.$2).toSet()..add(ConnectivityResult.none);
    final others = results.where((r) => !radios.contains(r)).map(_otherName).join(', ');
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: [
          for (final (i, (label, result)) in _rows.indexed)
            if (!_reported(result))
              _RadioRow(label: label, status: 'NOT REPORTED', color: colors.textMuted, divided: i > 0)
            else if (results.contains(result))
              _RadioRow(label: label, status: 'CONNECTED', color: colors.semanticEmber, divided: i > 0)
            else
              _RadioRow(label: label, status: 'NOT CONNECTED', color: colors.semanticSage, divided: i > 0),
          if (others.isNotEmpty) _RadioRow(label: 'OTHER', status: others, color: colors.semanticEmber, divided: true),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final String status;
  final Color color;
  final bool divided;

  const _RadioRow({required this.label, required this.status, required this.color, required this.divided});

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
          Text(status, style: text.dataAddress.copyWith(color: color)),
        ],
      ),
    );
  }
}
