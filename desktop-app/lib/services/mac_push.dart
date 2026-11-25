import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Mac's side of pushed notifications: what Apple's push service knows
/// this Mac by, and the clicks on what it delivered while the app was closed.
abstract interface class MacPush {
  /// Which of Apple's push services this build was signed for, `development`
  /// or `production`: a token is only good at that one. Null when the build
  /// was signed for neither, and so cannot be pushed to.
  Future<String?> environment();

  /// Asks Apple for the token it knows this Mac by now. Throws when it cannot
  /// be had.
  Future<String> requestToken();

  /// Hands [onClick] the payload of every pushed notification the person
  /// clicks, the one whose click launched the app first.
  Future<void> listenToClicks(void Function(String payload) onClick);
}

/// Served by `PushNotifications.swift`.
class ChannelMacPush implements MacPush {
  const ChannelMacPush();

  static const channel = MethodChannel('com.quantus.desktop-wallet/push');

  @override
  Future<String?> environment() => channel.invokeMethod<String>('environment');

  @override
  Future<String> requestToken() async {
    final token = await channel.invokeMethod<String>('token');
    if (token == null) throw StateError('macOS answered without a push token');
    return token;
  }

  @override
  Future<void> listenToClicks(void Function(String payload) onClick) async {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'click') throw MissingPluginException('The app does not serve ${call.method}');
      onClick(call.arguments as String);
    });
    final launch = await channel.invokeMethod<String>('takeLaunchClick');
    if (launch != null) onClick(launch);
  }
}

final macPushProvider = Provider<MacPush>((ref) => const ChannelMacPush());
