import 'package:flutter/foundation.dart';

class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableSwap;
  final bool enableEncryptedAccount;
  final bool enableMultisig;

  /// Asset id 1Click lists QTC under, when the listing cannot be told apart by
  /// its chain code; null leaves that to the listing.
  final String? swapQuantusAssetId;

  /// Whether this device's location may use NEAR Intents. Quersi decides it
  /// from the request's country and adds it to the config it serves; false
  /// until a server has said otherwise, so the gate fails closed.
  final bool geoNearAllowed;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableSwap,
    required this.enableEncryptedAccount,
    required this.enableMultisig,
    this.swapQuantusAssetId,
    required this.geoNearAllowed,
  });

  /// Swap is offered when the flag is on and the location allows NEAR Intents.
  bool get swapAvailable => enableSwap && geoNearAllowed;

  R match<R>({
    required R Function(
      bool enableTestButtons,
      bool enableKeystoneHardwareWallet,
      bool enableHighSecurity,
      bool enableRemoteNotifications,
      bool enableSwap,
      bool enableEncryptedAccount,
      bool enableMultisig,
      String? swapQuantusAssetId,
      bool geoNearAllowed,
    )
    fn,
  }) {
    return fn(
      enableTestButtons,
      enableKeystoneHardwareWallet,
      enableHighSecurity,
      enableRemoteNotifications,
      enableSwap,
      enableEncryptedAccount,
      enableMultisig,
      swapQuantusAssetId,
      geoNearAllowed,
    );
  }

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: true,
    enableHighSecurity: false,
    enableRemoteNotifications: true,
    enableSwap: true,
    enableEncryptedAccount: true,
    enableMultisig: true,
    geoNearAllowed: false,
  );

  Map<String, dynamic> toCacheJson() {
    return match(
      fn: (test, keystone, security, notifications, swap, encrypted, multisig, swapQuantusAssetId, geoNearAllowed) => {
        'enableTestButtons': test,
        'enableKeystoneHardwareWallet': keystone,
        'enableHighSecurity': security,
        'enableRemoteNotifications': notifications,
        'enableSwap': swap,
        'enableEncryptedAccount': encrypted,
        'enableMultisig': multisig,
        'swapQuantusAssetId': swapQuantusAssetId,
        'geoNearAllowed': geoNearAllowed,
      },
    );
  }

  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) {
    final swapQuantusAssetId = json['swapQuantusAssetId'] as String?;
    return RemoteConfigModel(
      enableTestButtons: json['enableTestButtons'] ?? defaults.enableTestButtons,
      enableKeystoneHardwareWallet: json['enableKeystoneHardwareWallet'] ?? defaults.enableKeystoneHardwareWallet,
      enableHighSecurity: json['enableHighSecurity'] ?? defaults.enableHighSecurity,
      enableRemoteNotifications: json['enableRemoteNotifications'] ?? defaults.enableRemoteNotifications,
      enableSwap: json['enableSwap'] ?? defaults.enableSwap,
      enableEncryptedAccount: json['enableEncryptedAccount'] ?? defaults.enableEncryptedAccount,
      enableMultisig: json['enableMultisig'] ?? defaults.enableMultisig,
      swapQuantusAssetId: swapQuantusAssetId == null || swapQuantusAssetId.isEmpty ? null : swapQuantusAssetId,
      geoNearAllowed: json['geoNearAllowed'] ?? defaults.geoNearAllowed,
    );
  }

  @override
  bool operator ==(Object other) => other is RemoteConfigModel && mapEquals(toCacheJson(), other.toCacheJson());

  @override
  int get hashCode => Object.hashAll(toCacheJson().values);
}
