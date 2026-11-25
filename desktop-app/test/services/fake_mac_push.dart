import 'dart:async';

import 'package:quantus_desktop_wallet/services/mac_push.dart';

/// Stands in for the Mac's side of pushed notifications: answers as
/// [environmentOfBuild], [token] and [tokenError] say, and clicks as a person
/// would.
class FakeMacPush implements MacPush {
  FakeMacPush({this.environmentOfBuild = 'development', this.token = 'mac-token', this.launchedBy});

  /// Which of Apple's push services the build was signed for; null when for
  /// neither.
  String? environmentOfBuild;

  /// The token Apple gives this Mac when asked.
  String token;

  /// What asking for the token throws, when it cannot be had.
  Object? tokenError;
  var tokenRequests = 0;

  /// When set, Apple answers a request for the token only once it completes.
  Completer<void>? holdToken;

  /// The payload of the pushed notification whose click launched the app, if
  /// one did.
  final String? launchedBy;
  void Function(String payload)? _onClick;

  @override
  Future<String?> environment() async => environmentOfBuild;

  @override
  Future<String> requestToken() async {
    tokenRequests++;
    await holdToken?.future;
    final error = tokenError;
    if (error != null) throw error;
    return token;
  }

  @override
  Future<void> listenToClicks(void Function(String payload) onClick) async {
    _onClick = onClick;
    final launch = launchedBy;
    if (launch != null) onClick(launch);
  }

  /// Clicks a pushed notification carrying [payload].
  void click(String payload) {
    final onClick = _onClick;
    if (onClick == null) throw StateError('Clicked a pushed notification before the app listened');
    onClick(payload);
  }
}
