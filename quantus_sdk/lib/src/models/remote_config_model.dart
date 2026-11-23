import 'package:flutter/foundation.dart';

class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableEncryptedAccount;
  final bool enableMultisig;

  /// Whether an encrypted send checks its recipient against 1Click's deposit
  /// addresses. Off, the check always lets the send through.
  final bool enableOneClickNearWarning;

  /// Asset id 1Click lists QTC under, when the listing cannot be told apart by
  /// its chain code; null leaves that to the listing.
  final String? swapQuantusAssetId;

  /// Whether this device's location may use NEAR Intents. Quersi decides it
  /// from the request's country and adds it to the config it serves; a config
  /// without a verdict allows it.
  final bool geoNearAllowed;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableEncryptedAccount,
    required this.enableMultisig,
    required this.enableOneClickNearWarning,
    this.swapQuantusAssetId,
    required this.geoNearAllowed,
  });

  /// Swap is offered where the location allows NEAR Intents.
  bool get swapAvailable => geoNearAllowed;

  R match<R>({
    required R Function(
      bool enableTestButtons,
      bool enableKeystoneHardwareWallet,
      bool enableHighSecurity,
      bool enableRemoteNotifications,
      bool enableEncryptedAccount,
      bool enableMultisig,
      bool enableOneClickNearWarning,
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
      enableEncryptedAccount,
      enableMultisig,
      enableOneClickNearWarning,
      swapQuantusAssetId,
      geoNearAllowed,
    );
  }

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: true,
    enableHighSecurity: false,
    enableRemoteNotifications: true,
    enableEncryptedAccount: true,
    enableMultisig: true,
    enableOneClickNearWarning: true,
    geoNearAllowed: true,
  );

  Map<String, dynamic> toCacheJson() {
    return match(
      fn:
          (
            test,
            keystone,
            security,
            notifications,
            encrypted,
            multisig,
            oneClickWarning,
            swapQuantusAssetId,
            geoNearAllowed,
          ) => {
            'enableTestButtons': test,
            'enableKeystoneHardwareWallet': keystone,
            'enableHighSecurity': security,
            'enableRemoteNotifications': notifications,
            'enableEncryptedAccount': encrypted,
            'enableMultisig': multisig,
            'enableOneClickNearWarning': oneClickWarning,
            'swapQuantusAssetId': swapQuantusAssetId,
            'geoNearAllowed': geoNearAllowed,
          },
    );
  }

  static String? _optionalString(Object? value) => value is String && value.isNotEmpty ? value : null;

  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) {
    return RemoteConfigModel(
      enableTestButtons: json['enableTestButtons'] ?? defaults.enableTestButtons,
      enableKeystoneHardwareWallet: json['enableKeystoneHardwareWallet'] ?? defaults.enableKeystoneHardwareWallet,
      enableHighSecurity: json['enableHighSecurity'] ?? defaults.enableHighSecurity,
      enableRemoteNotifications: json['enableRemoteNotifications'] ?? defaults.enableRemoteNotifications,
      enableEncryptedAccount: json['enableEncryptedAccount'] ?? defaults.enableEncryptedAccount,
      enableMultisig: json['enableMultisig'] ?? defaults.enableMultisig,
      enableOneClickNearWarning: json['enableOneClickNearWarning'] ?? defaults.enableOneClickNearWarning,
      swapQuantusAssetId: _optionalString(json['swapQuantusAssetId']),
      geoNearAllowed: json['geoNearAllowed'] ?? defaults.geoNearAllowed,
    );
  }

  @override
  bool operator ==(Object other) => other is RemoteConfigModel && mapEquals(toCacheJson(), other.toCacheJson());

  @override
  int get hashCode => Object.hashAll(toCacheJson().values);
}
