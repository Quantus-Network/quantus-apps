import 'package:collection/collection.dart';
import 'package:quantus_sdk/src/models/network_endpoints.dart';

class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableSwap;
  final bool enableEncryptedAccount;
  final bool enableMultisig;
  final NetworkEndpoints endpoints;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableSwap,
    required this.enableEncryptedAccount,
    required this.enableMultisig,
    this.endpoints = NetworkEndpoints.defaults,
  });

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: true,
    enableHighSecurity: false,
    enableRemoteNotifications: true,
    enableSwap: true,
    enableEncryptedAccount: true,
    enableMultisig: true,
  );

  static const _equality = DeepCollectionEquality();

  Map<String, dynamic> toCacheJson() => {
    'enableTestButtons': enableTestButtons,
    'enableKeystoneHardwareWallet': enableKeystoneHardwareWallet,
    'enableHighSecurity': enableHighSecurity,
    'enableRemoteNotifications': enableRemoteNotifications,
    'enableSwap': enableSwap,
    'enableEncryptedAccount': enableEncryptedAccount,
    'enableMultisig': enableMultisig,
    'endpoints': endpoints.toJson(),
  };

  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) => RemoteConfigModel(
    enableTestButtons: json['enableTestButtons'] ?? defaults.enableTestButtons,
    enableKeystoneHardwareWallet: json['enableKeystoneHardwareWallet'] ?? defaults.enableKeystoneHardwareWallet,
    enableHighSecurity: json['enableHighSecurity'] ?? defaults.enableHighSecurity,
    enableRemoteNotifications: json['enableRemoteNotifications'] ?? defaults.enableRemoteNotifications,
    enableSwap: json['enableSwap'] ?? defaults.enableSwap,
    enableEncryptedAccount: json['enableEncryptedAccount'] ?? defaults.enableEncryptedAccount,
    enableMultisig: json['enableMultisig'] ?? defaults.enableMultisig,
    endpoints: NetworkEndpoints.fromJson(json['endpoints'] ?? const {}),
  );

  @override
  bool operator ==(Object other) => other is RemoteConfigModel && _equality.equals(toCacheJson(), other.toCacheJson());

  @override
  int get hashCode => _equality.hash(toCacheJson());
}
