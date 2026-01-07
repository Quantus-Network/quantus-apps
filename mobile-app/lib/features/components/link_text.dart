import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkText extends StatelessWidget {
  final String label;
  final String url;
  final TextStyle? textStyle;

  const LinkText({super.key, required this.label, required this.url, this.textStyle});

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = (textStyle ?? context.themeText.paragraph)?.copyWith(
      decoration: TextDecoration.underline,
    );

    return GestureDetector(
      child: Text(label, style: effectiveTextStyle),
      onTap: () {
        final Uri uri = Uri.parse(url);
        launchUrl(uri);
      },
    );
  }
}
