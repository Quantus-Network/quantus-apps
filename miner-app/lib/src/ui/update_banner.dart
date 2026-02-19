import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class UpdateBanner extends StatelessWidget {
  final String version;
  final String message;
  final double? updateProgress;
  final VoidCallback onUpdate;
  final VoidCallback? onDismiss;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const UpdateBanner({
    super.key,
    required this.version,
    this.message = 'A new version is available',
    required this.onUpdate,
    this.updateProgress,
    this.onDismiss,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blue.shade500,
        boxShadow: [BoxShadow(color: Colors.black.useOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon ?? Icons.download, color: textColor ?? Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(color: textColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version $version',
                      style: TextStyle(color: (textColor ?? Colors.white).useOpacity(0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (updateProgress != null)
                SizedBox(width: 100, child: LinearProgressIndicator(value: updateProgress))
              else
                ElevatedButton(
                  onPressed: onUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (onDismiss != null && updateProgress == null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, color: textColor ?? Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
