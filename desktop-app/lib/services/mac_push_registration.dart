import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/providers/notification_click_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/mac_push.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/remote_notifications_registration.dart';
import 'package:wallet_core/services/telemetry.dart';

/// The push notification service the desktop registers with.
final senotiClientProvider = Provider<SenotiAuthClient>((ref) => SenotiAuthClient(AppConstants.senotiEndpoint));

/// Registers this Mac with the push service, which then has Apple show what
/// the wallet's accounts receive while the app is closed.
///
/// Only while the person wants notifications and macOS allows them, and only
/// from a build signed to receive pushes: any other registers nothing, as
/// Windows and Linux do. A reset removes the Mac whatever they are set to.
class MacPushRegistration implements PushRegistration {
  MacPushRegistration(this._ref);

  /// What the push service calls a Mac.
  static const platform = 'macos';

  final Ref _ref;

  /// Whether the person wants notifications and macOS allows them.
  bool get isWanted =>
      _ref.read(notificationConfigProvider).enabled &&
      _ref.read(desktopLocalNotificationsProvider) is NotificationsAllowed;

  /// The addresses the push service may be told of, once the wallet's
  /// accounts are known: never an Encrypted account's.
  List<String>? get notifiableAddresses {
    final accounts = _ref.read(accountsProvider).value;
    final multisigs = _ref.read(multisigAccountsProvider).value;
    if (accounts == null || multisigs == null) return null;
    return SenotiService.notifiableAddresses(accounts, multisigs);
  }

  /// Registers the Mac for every address that may be told of. Before the
  /// accounts are known there is nothing to register: [MacPushSync] does it
  /// when they are.
  @override
  Future<void> registerDevice() async {
    if (!isWanted) return;
    final addresses = notifiableAddresses;
    if (addresses == null || addresses.isEmpty) return;
    final push = _ref.read(macPushProvider);
    final environment = await push.environment();
    if (environment == null) return _notSignedForPushes();
    await _ref
        .read(senotiClientProvider)
        .registerDevice(
          addresses: addresses,
          deviceToken: await push.requestToken(),
          platform: platform,
          apnsEnvironment: environment,
        );
  }

  /// Nothing to do here: [MacPushSync] registers the wallet's addresses
  /// whenever its accounts change, so that no account flow waits for Apple
  /// to answer with this Mac's token.
  @override
  Future<void> registerAddress(String address) async {}

  /// A reset does not wait for this and cannot be failed by it, so a failure
  /// is reported here.
  @override
  Future<void> unregister() async {
    try {
      final push = _ref.read(macPushProvider);
      if (await push.environment() == null) return _notSignedForPushes();
      await _ref.read(senotiClientProvider).unregisterDevice(deviceToken: await push.requestToken());
    } catch (e) {
      quantusPrint('Removing this Mac from the push service failed: $e');
      _ref.read(telemetryProvider).sendError('desktop_push_unregister_failed', error: e);
    }
  }

  void _notSignedForPushes() => quantusPrint('This build was not signed to receive pushes: nothing to register');
}

final macPushRegistrationProvider = Provider<MacPushRegistration>(MacPushRegistration.new);

/// Keeps this Mac's registration as the person's choices and the wallet's
/// accounts are: registered while notifications are wanted and allowed, for
/// the accounts the wallet has now, and removed once they are switched off.
/// Clicks on what was pushed open what it was about.
class MacPushSync {
  MacPushSync(this._ref) {
    _ref.listen(desktopLocalNotificationsProvider, (_, _) => _changed());
    _ref.listen(notificationConfigProvider.select((config) => config.enabled), (_, _) => _changed());
    _ref.listen(remoteConfigProvider.select((config) => config.enableRemoteNotifications), (_, _) => _changed());
    _ref.listen(accountsProvider, (_, _) => _changed());
    _ref.listen(multisigAccountsProvider, (_, _) => _changed());
    unawaited(_listenToClicks());
    _changed();
  }

  final Ref _ref;

  /// The addresses the Mac was last registered for; null while it is not.
  String? _registeredFor;

  /// Whether a look at what changed is already waiting its turn.
  var _isQueued = false;
  Future<void> _turn = Future.value();

  Future<void> _listenToClicks() async {
    try {
      await _ref.read(macPushProvider).listenToClicks((payload) => _ref.read(notificationClickProvider).open(payload));
    } catch (e) {
      quantusPrint('Listening for clicks on pushed notifications failed: $e');
      if (_ref.mounted) _ref.read(telemetryProvider).sendError('desktop_push_clicks_unavailable', error: e);
    }
  }

  /// One registration or removal at a time, each for the state it finds.
  void _changed() {
    if (_isQueued) return;
    _isQueued = true;
    _turn = _turn.then((_) {
      _isQueued = false;
      return _reconcile();
    });
  }

  Future<void> _reconcile() async {
    if (!_ref.mounted) return;
    final registration = _ref.read(macPushRegistrationProvider);
    final isWanted = registration.isWanted && _ref.read(remoteConfigProvider).enableRemoteNotifications;
    if (!isWanted) {
      if (_registeredFor == null) return;
      _registeredFor = null;
      await registration.unregister();
      return;
    }
    final addresses = registration.notifiableAddresses;
    if (addresses == null) return;
    // A reset removed the Mac itself: the wallet that comes next is new to
    // the push service, even with the same accounts.
    final key = addresses.isEmpty ? null : addresses.join('\n');
    if (key == null || key == _registeredFor) {
      _registeredFor = key;
      return;
    }
    _registeredFor = key;
    await registerForRemoteNotificationsBestEffort(_ref.read);
  }
}

/// Started with the app, on a Mac: Windows and Linux have no push service
/// that reaches a closed app.
final macPushSyncProvider = Provider<MacPushSync?>(
  (ref) => defaultTargetPlatform == TargetPlatform.macOS ? MacPushSync(ref) : null,
);
