import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:swap_live_activity_channel/swap_live_activity_channel.dart';

/// FCM data `type` for an Android swap card update.
///
/// Senoti sends the stored `content_state` map, with the new phase filled in,
/// as the data message. A nested map is a JSON string under `content_state`
/// because FCM data values are strings. Either shape is the same card.
const swapLiveActivityMessageType = 'swap_live_activity';

const _methodChannel = MethodChannel(swapLiveActivityChannel);

const _stringFields = [
  'phase',
  'headline',
  'brand',
  'idleBrand',
  'fromAmount',
  'fromSymbol',
  'toAmount',
  'toSymbol',
  'chain',
  'fromLabel',
  'toLabel',
  'chainLabel',
  'openToCheck',
  'agoLabel',
  'key',
  'channelName',
];

/// The card currently stored on the device, if the native side has one.
class SwapLiveCardSnapshot {
  final String? key;
  final String? dismissedKey;

  const SwapLiveCardSnapshot({this.key, this.dismissedKey});
}

/// The card to draw for [data], or null when the push must not change the
/// lock screen. Only the swap already on screen is updated, and a card the
/// user dismissed stays gone.
Map<String, Object?>? swapLiveActivityPushUpdate(Map<String, dynamic> data, SwapLiveCardSnapshot? card) {
  if (data['type'] != swapLiveActivityMessageType) return null;
  final payload = swapLiveActivityPayload(data);
  final key = payload['key'];
  final phase = payload['phase'];
  if (key is! String || key.isEmpty || phase is! String || phase.isEmpty) return null;
  if (card == null || card.key != key || card.dismissedKey == key) return null;
  return payload;
}

/// `content_state` as the native card draws it. Strings from FCM are coerced
/// back to the bools, numbers, and nulls [SwapLiveActivityContent.toPayload] sent.
Map<String, Object?> swapLiveActivityPayload(Map<String, dynamic> data) {
  final fields = _fields(data);
  return {
    for (final key in _stringFields) key: fields[key]?.toString() ?? '',
    'failure': _nullableText(fields['failure']),
    'progress': _double(fields['progress']),
    'showProgress': _bool(fields['showProgress']),
    'endsAt': _epoch(fields['endsAt']),
    'updatedAt': _epoch(fields['updatedAt']),
    'staleAt': _epoch(fields['staleAt']),
    'holdsProcess': _bool(fields['holdsProcess']),
  };
}

/// Applies [data] to the Android card. Returns whether [data] was a swap update,
/// including one that did not change the card. Other pushes return false so the
/// transaction notification path can handle them.
Future<bool> deliverSwapLiveActivityPush(Map<String, dynamic> data) async {
  if (data['type'] != swapLiveActivityMessageType) return false;
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    final raw = await _methodChannel.invokeMethod<dynamic>('card');
    final update = swapLiveActivityPushUpdate(data, _snapshot(raw));
    if (update != null) await _methodChannel.invokeMethod<void>('show', update);
  } on MissingPluginException catch (error) {
    quantusPrint('Swap live activity push had no native handler: $error');
  } on PlatformException catch (error) {
    quantusPrint('Swap live activity push failed: $error');
  }
  return true;
}

Map<String, dynamic> _fields(Map<String, dynamic> data) {
  final nested = data['content_state'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  if (nested is String && nested.isNotEmpty) {
    try {
      final decoded = jsonDecode(nested);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      quantusPrint('Swap live activity content_state was not JSON');
    }
  }
  return data;
}

SwapLiveCardSnapshot? _snapshot(dynamic raw) {
  if (raw is! Map) return null;
  return SwapLiveCardSnapshot(key: _nullableText(raw['key']), dismissedKey: _nullableText(raw['dismissedKey']));
}

String? _nullableText(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty || text == 'null') return null;
  return text;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value == 'true';
  if (value is num) return value != 0;
  return false;
}

int? _epoch(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    if (value.isEmpty || value == 'null') return null;
    return int.tryParse(value);
  }
  return null;
}
