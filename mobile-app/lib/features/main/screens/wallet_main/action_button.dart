import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

enum ActionType { send, receive, bridge, swap }

class ActionButton extends StatelessWidget {
  final ActionType type;
  final VoidCallback onPressed;
  final bool disabled;

  const ActionButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.disabled = false,
  });

  String get label {
    switch (type) {
      case ActionType.send:
        return 'SEND';
      case ActionType.receive:
        return 'RECEIVE';
      case ActionType.bridge:
        return 'BRIDGE';
      case ActionType.swap:
        return 'SWAP';
    }
  }

  Widget get iconWidget {
    switch (type) {
      case ActionType.send:
        return Image.asset('assets/transaction/send_icon.png');
      case ActionType.receive:
        return SvgPicture.asset(
          'assets/transaction/receive_icon.svg',
          width: 19,
        );
      case ActionType.bridge:
        return SvgPicture.asset(
          'assets/transaction/bridge_icon.svg',
          width: 19,
        );
      case ActionType.swap:
        return SvgPicture.asset('assets/transaction/swap_icon.svg', width: 19);
    }
  }

  String get frameImagePath {
    switch (type) {
      case ActionType.send:
        return 'assets/send_btn_decoration.png';
      case ActionType.receive:
        return 'assets/receive_btn_decoration.png';
      case ActionType.bridge:
        return 'assets/bridge_btn_decoration.png';
      case ActionType.swap:
        return 'assets/swap_btn_decoration.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = disabled ? Colors.white.useOpacity(0.5) : Colors.white;
    final bgColor = Colors.black;

    Widget finalIconWidget = iconWidget;
    if (iconWidget is SvgPicture) {
      finalIconWidget = SvgPicture.asset(
        ((iconWidget as SvgPicture).bytesLoader as SvgAssetLoader).assetName,
        width: context.themeSize.mainMenuWidth,
        height: context.themeSize.mainMenuHeight,
      );
    } else if (iconWidget is Icon) {
      finalIconWidget = Icon(
        (iconWidget as Icon).icon,
        color: color,
        size: context.themeSize.mainMenuHeight,
      );
    } else if (iconWidget is Image) {
      finalIconWidget = SizedBox(
        width: context.themeSize.mainMenuWidth,
        height: context.themeSize.mainMenuHeight,
        child: iconWidget,
      );
    }

    return Opacity(
      opacity: disabled ? 0.7 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 145,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            image: DecorationImage(
              image: AssetImage(frameImagePath),
              fit: BoxFit.contain,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              finalIconWidget,
              const SizedBox(width: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.themeText.tag,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
