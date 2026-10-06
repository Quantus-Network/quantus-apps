import 'package:flutter/foundation.dart';

class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableSwap;
  final bool enableEncryptedAccount;
  final bool enableMultisig;

  /// Whether an encrypted send checks its recipient against 1Click's deposit
  /// addresses. Off, the check always lets the send through.
  final bool enableOneClickNearWarning;

  /// Whether Max may send with `transfer_all`. Off, Max is sized from the fee
  /// and sent as a plain transfer: NEAR Intents cannot credit a `transfer_all`
  /// deposit yet.
  final bool enableTransferAllCall;

  /// Asset id 1Click lists QTC under, when the listing cannot be told apart by
  /// its chain code; null leaves that to the listing.
  final String? swapQuantusAssetId;

  /// Whether this device's location may use NEAR Intents. Quersi decides it
  /// from the request's country and adds it to the config it serves. False
  /// until this launch's server answer allows it: a cached verdict is never
  /// trusted, the device may have moved, so the gate fails closed.
  final bool geoNearAllowed;

  /// 1Click partner JWT, sent as X-API-Key to attribute volume and lower the
  /// platform fee; null sends no key. Served under `near.partner.jwt`.
  final String? nearPartnerJwt;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableSwap,
    required this.enableEncryptedAccount,
    required this.enableMultisig,
    required this.enableOneClickNearWarning,
    required this.enableTransferAllCall,
    this.swapQuantusAssetId,
    required this.geoNearAllowed,
    this.nearPartnerJwt,
  });

  /// Swap is offered when the flag is on and the location allows NEAR Intents.
  bool get swapAvailable => enableSwap && geoNearAllowed;

  RemoteConfigModel copyWith({bool? geoNearAllowed}) => RemoteConfigModel(
    enableTestButtons: enableTestButtons,
    enableKeystoneHardwareWallet: enableKeystoneHardwareWallet,
    enableHighSecurity: enableHighSecurity,
    enableRemoteNotifications: enableRemoteNotifications,
    enableSwap: enableSwap,
    enableEncryptedAccount: enableEncryptedAccount,
    enableMultisig: enableMultisig,
    enableOneClickNearWarning: enableOneClickNearWarning,
    enableTransferAllCall: enableTransferAllCall,
    swapQuantusAssetId: swapQuantusAssetId,
    geoNearAllowed: geoNearAllowed ?? this.geoNearAllowed,
    nearPartnerJwt: nearPartnerJwt,
  );

  R match<R>({
    required R Function(
      bool enableTestButtons,
      bool enableKeystoneHardwareWallet,
      bool enableHighSecurity,
      bool enableRemoteNotifications,
      bool enableSwap,
      bool enableEncryptedAccount,
      bool enableMultisig,
      bool enableOneClickNearWarning,
      bool enableTransferAllCall,
      String? swapQuantusAssetId,
      bool geoNearAllowed,
      String? nearPartnerJwt,
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
      enableOneClickNearWarning,
      enableTransferAllCall,
      swapQuantusAssetId,
      geoNearAllowed,
      nearPartnerJwt,
    );
  }

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: true,
    enableHighSecurity: false,
    enableRemoteNotifications: true,
    enableSwap: false,
    enableEncryptedAccount: true,
    enableMultisig: true,
    enableOneClickNearWarning: true,
    enableTransferAllCall: false,
    geoNearAllowed: false,
  );

  Map<String, dynamic> toCacheJson() {
    return match(
      fn:
          (
            test,
            keystone,
            security,
            notifications,
            swap,
            encrypted,
            multisig,
            oneClickWarning,
            transferAll,
            swapQuantusAssetId,
            geoNearAllowed,
            nearPartnerJwt,
          ) => {
            'enableTestButtons': test,
            'enableKeystoneHardwareWallet': keystone,
            'enableHighSecurity': security,
            'enableRemoteNotifications': notifications,
            'enableSwap': swap,
            'enableEncryptedAccount': encrypted,
            'enableMultisig': multisig,
            'enableOneClickNearWarning': oneClickWarning,
            'enableTransferAllCall': transferAll,
            'swapQuantusAssetId': swapQuantusAssetId,
            'geoNearAllowed': geoNearAllowed,
            'near.partner.jwt': nearPartnerJwt,
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
      enableSwap: json['enableSwap'] ?? defaults.enableSwap,
      enableEncryptedAccount: json['enableEncryptedAccount'] ?? defaults.enableEncryptedAccount,
      enableMultisig: json['enableMultisig'] ?? defaults.enableMultisig,
      enableOneClickNearWarning: json['enableOneClickNearWarning'] ?? defaults.enableOneClickNearWarning,
      enableTransferAllCall: json['enableTransferAllCall'] ?? defaults.enableTransferAllCall,
      swapQuantusAssetId: _optionalString(json['swapQuantusAssetId']),
      geoNearAllowed: json['geoNearAllowed'] ?? defaults.geoNearAllowed,
      nearPartnerJwt: _optionalString(json['near.partner.jwt']),
    );
  }

  @override
  bool operator ==(Object other) => other is RemoteConfigModel && mapEquals(toCacheJson(), other.toCacheJson());

  @override
  int get hashCode => Object.hashAll(toCacheJson().values);
}
