import 'dart:async';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// A camera reading QR codes, [width] wide: its [preview] under the scan
/// frame or, where it has failed, why, in its place, with Try Again and,
/// where it may not be used, a way to the system's settings for it.
class QrCameraBox extends ConsumerWidget {
  const QrCameraBox({
    super.key,
    required this.preview,
    required this.width,
    required this.failure,
    required this.onTryAgain,
  });

  /// The camera's picture: one for the camera's life, so a rebuild never
  /// reattaches it.
  final Widget preview;
  final double width;
  final QrCameraFailure? failure;
  final VoidCallback onTryAgain;

  /// The system's page for the camera's privacy, where it has one.
  static Uri? get _cameraSettings => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_Camera'),
    TargetPlatform.windows => Uri.parse('ms-settings:privacy-webcam'),
    _ => null,
  };

  static ({String title, String body}) _failureText(AppLocalizations l10n, QrCameraFailure failure) =>
      switch (failure) {
        QrCameraFailure.noCamera => (title: l10n.desktopCameraNoneTitle, body: l10n.desktopCameraNoneBody),
        QrCameraFailure.permissionDenied => (
          title: l10n.desktopCameraPermissionTitle,
          body: switch (defaultTargetPlatform) {
            TargetPlatform.macOS => l10n.desktopCameraPermissionMac,
            TargetPlatform.windows => l10n.desktopCameraPermissionWindows,
            _ => l10n.desktopCameraPermissionLinux,
          },
        ),
        QrCameraFailure.busy => (title: l10n.desktopCameraBusyTitle, body: l10n.desktopCameraBusyBody),
        QrCameraFailure.unsupported => (
          title: l10n.desktopCameraUnsupportedTitle,
          body: l10n.desktopCameraUnsupportedBody,
        ),
        QrCameraFailure.mediaUnavailable => (title: l10n.desktopCameraMediaTitle, body: l10n.desktopCameraMediaBody),
        QrCameraFailure.stopped => (title: l10n.desktopCameraStoppedTitle, body: l10n.desktopCameraStoppedBody),
        QrCameraFailure.failed => (title: l10n.desktopCameraFailedTitle, body: l10n.desktopCameraFailedBody),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final failure = this.failure;

    Future<void> openSettings(Uri url) async {
      try {
        await ref.read(openExternalUrlProvider)(url);
      } catch (e) {
        // The notice already says where to go.
        quantusPrint('Opening the camera settings failed: $e');
      }
    }

    return ClipRRect(
      borderRadius: context.radiusV3.mdBorder,
      child: Container(
        width: width,
        height: width * 0.72,
        decoration: BoxDecoration(
          color: colors.bgVoid,
          border: Border.all(color: colors.borderHairline),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            preview,
            if (failure == null)
              Center(
                child: SizedBox.square(
                  dimension: width * 0.6,
                  child: CustomPaint(
                    painter: ScanFramePainter(
                      accent: colors.accentFlare,
                      scrim: colors.bgVoid.useOpacity(0.35),
                      radius: context.radiusV3.md,
                    ),
                  ),
                ),
              )
            else
              ColoredBox(
                color: colors.bgVoid,
                child: _CameraNotice(
                  text: _failureText(l10n, failure),
                  tryAgainLabel: l10n.commonTryAgain,
                  onTryAgain: onTryAgain,
                  settingsLabel: l10n.desktopCameraOpenSettings,
                  onOpenSettings: switch ((failure, _cameraSettings)) {
                    (QrCameraFailure.permissionDenied, final Uri url) => () => unawaited(openSettings(url)),
                    _ => null,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Why the camera shows no picture, in its place, and what can be done.
class _CameraNotice extends StatelessWidget {
  const _CameraNotice({
    required this.text,
    required this.tryAgainLabel,
    required this.onTryAgain,
    required this.settingsLabel,
    required this.onOpenSettings,
  });

  final ({String title, String body}) text;
  final String tryAgainLabel;
  final VoidCallback onTryAgain;
  final String settingsLabel;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final style = context.themeTextV3;
    final onOpenSettings = this.onOpenSettings;

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text.title,
              textAlign: TextAlign.center,
              style: style.bodyEmphasis.copyWith(color: colors.textContent),
            ),
            const SizedBox(height: 6),
            Text(
              text.body,
              textAlign: TextAlign.center,
              style: style.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            // Side by side when they fit, each as wide as its label.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpenSettings != null)
                  IntrinsicWidth(
                    child: SheetButton(label: settingsLabel, kind: SheetButtonKind.secondary, onTap: onOpenSettings),
                  ),
                IntrinsicWidth(
                  child: SheetButton(label: tryAgainLabel, kind: SheetButtonKind.secondary, onTap: onTryAgain),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
