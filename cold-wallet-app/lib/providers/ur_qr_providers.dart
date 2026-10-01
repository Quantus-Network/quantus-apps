import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';

/// Bytes to show as a UR QR, equal by content so they can key a provider
/// family: two screens showing the same bytes share one set of frames.
@immutable
class UrPayload {
  final Uint8List bytes;

  const UrPayload(this.bytes);

  @override
  bool operator ==(Object other) => other is UrPayload && listEquals(bytes, other.bytes);

  @override
  int get hashCode => Object.hashAll(bytes);
}

/// The UR frames for a payload at the user's bytes-per-frame setting.
/// Recomputed only when that setting changes; dropped when nothing shows it.
final urQrFramesProvider = Provider.autoDispose.family<List<String>, UrPayload>((ref, payload) {
  final qrBytes = ref.watch(coldSettingsProvider.select((s) => s.qrBytes));
  return encodeUrForQr(data: payload.bytes, maxFragmentLength: qrBytes);
});

/// Whether the QR animation on screen is paused, as while its tuning sheet is
/// open. One QR is shown at a time, so one flag serves every QR screen.
class QrPausedController extends Notifier<bool> {
  @override
  bool build() => false;

  void pause() => state = true;

  void resume() => state = false;
}

final qrPausedProvider = NotifierProvider.autoDispose<QrPausedController, bool>(QrPausedController.new);
