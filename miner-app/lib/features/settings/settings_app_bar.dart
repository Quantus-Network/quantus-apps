import 'package:flutter/material.dart';
import 'package:quantus_miner/src/shared/extensions/theme_extensions.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsAppBar extends StatefulWidget {
  const SettingsAppBar({super.key});

  @override
  State<SettingsAppBar> createState() => _SettingsAppBarState();
}

class _SettingsAppBarState extends State<SettingsAppBar> {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      pinned: false,
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        child: BackdropFilter(
          filter: ColorFilter.mode(Colors.black.useOpacity(0.1), BlendMode.srcOver),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.useOpacity(0.1), Colors.white.useOpacity(0.05)],
              ),
              border: Border(bottom: BorderSide(color: Colors.white.useOpacity(0.1), width: 1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(child: Text('Settings', style: context.textTheme.titleMedium)),
            ),
          ),
        ),
      ),
    );
  }
}
