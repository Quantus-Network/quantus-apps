import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/models/swap_quote.dart';

class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableSwap;

  /// Android's own swap flag, so the two stores can be switched apart.
  final bool enableSwapAndroid;
  final bool enableEncryptedAccount;
  final bool enableMultisig;

  /// Whether an encrypted send checks its recipient against 1Click's deposit
  /// addresses. Off, the check always lets the send through.
  final bool enableOneClickNearWarning;

  /// Asset id 1Click lists QTC under, when the listing cannot be told apart by
  /// its chain code; null leaves that to the listing.
  final String? swapQuantusAssetId;

  /// Whether this device's location may use NEAR Intents. Quersi decides it
  /// from the request's country and adds it to the config it serves. False
  /// until this launch's server answer allows it: a cached verdict is never
  /// trusted, the device may have moved, so the gate fails closed.
  final bool geoNearAllowed;

  /// Where the 1Click API is called: our proxy, which adds the partner key
  /// and the app fee itself, or 1Click directly, which takes both from here.
  /// Only ever served, never built in: null offers no swap. The two are
  /// swapped by changing this, without a release.
  final String? oneClickEndpoint;

  /// 1Click partner JWT, sent as X-API-Key; null sends none, which is all the
  /// proxy expects. Served under `near.partner.jwt`.
  final String? nearPartnerJwt;

  /// The app's fee on every swap, from `swapFeeBips` and `swapFeeRecipient`;
  /// null sends none. The proxy replaces whatever is sent with its own.
  final SwapAppFee? swapAppFee;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableSwap,
    required this.enableSwapAndroid,
    required this.enableEncryptedAccount,
    required this.enableMultisig,
    required this.enableOneClickNearWarning,
    this.swapQuantusAssetId,
    required this.geoNearAllowed,
    this.oneClickEndpoint,
    this.nearPartnerJwt,
    this.swapAppFee,
  });

  /// Swap is offered once a 1Click endpoint is served, when the platform's
  /// flag is on and the location allows NEAR Intents, or always in a
  /// [AppConstants.swapAllowOverride] build.
  bool get swapAvailable =>
      oneClickEndpoint != null &&
      (AppConstants.swapAllowOverride ||
          ((defaultTargetPlatform == TargetPlatform.android ? enableSwapAndroid : enableSwap) && geoNearAllowed));

  RemoteConfigModel copyWith({bool? geoNearAllowed}) => RemoteConfigModel(
    enableTestButtons: enableTestButtons,
    enableKeystoneHardwareWallet: enableKeystoneHardwareWallet,
    enableHighSecurity: enableHighSecurity,
    enableRemoteNotifications: enableRemoteNotifications,
    enableSwap: enableSwap,
    enableSwapAndroid: enableSwapAndroid,
    enableEncryptedAccount: enableEncryptedAccount,
    enableMultisig: enableMultisig,
    enableOneClickNearWarning: enableOneClickNearWarning,
    swapQuantusAssetId: swapQuantusAssetId,
    geoNearAllowed: geoNearAllowed ?? this.geoNearAllowed,
    oneClickEndpoint: oneClickEndpoint,
    nearPartnerJwt: nearPartnerJwt,
    swapAppFee: swapAppFee,
  );

  R match<R>({
    required R Function(
      bool enableTestButtons,
      bool enableKeystoneHardwareWallet,
      bool enableHighSecurity,
      bool enableRemoteNotifications,
      bool enableSwap,
      bool enableSwapAndroid,
      bool enableEncryptedAccount,
      bool enableMultisig,
      bool enableOneClickNearWarning,
      String? swapQuantusAssetId,
      bool geoNearAllowed,
      String? oneClickEndpoint,
      String? nearPartnerJwt,
      SwapAppFee? swapAppFee,
    )
    fn,
  }) {
    return fn(
      enableTestButtons,
      enableKeystoneHardwareWallet,
      enableHighSecurity,
      enableRemoteNotifications,
      enableSwap,
      enableSwapAndroid,
      enableEncryptedAccount,
      enableMultisig,
      enableOneClickNearWarning,
      swapQuantusAssetId,
      geoNearAllowed,
      oneClickEndpoint,
      nearPartnerJwt,
      swapAppFee,
    );
  }

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: true,
    enableHighSecurity: false,
    enableRemoteNotifications: true,
    enableSwap: false,
    enableSwapAndroid: true,
    enableEncryptedAccount: true,
    enableMultisig: true,
    enableOneClickNearWarning: true,
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
            swapAndroid,
            encrypted,
            multisig,
            oneClickWarning,
            swapQuantusAssetId,
            geoNearAllowed,
            oneClickEndpoint,
            nearPartnerJwt,
            swapAppFee,
          ) => {
            'enableTestButtons': test,
            'enableKeystoneHardwareWallet': keystone,
            'enableHighSecurity': security,
            'enableRemoteNotifications': notifications,
            'enableSwap': swap,
            'enableSwapAndroid': swapAndroid,
            'enableEncryptedAccount': encrypted,
            'enableMultisig': multisig,
            'enableOneClickNearWarning': oneClickWarning,
            'swapQuantusAssetId': swapQuantusAssetId,
            'geoNearAllowed': geoNearAllowed,
            'oneClickEndpoint': oneClickEndpoint,
            'near.partner.jwt': nearPartnerJwt,
            'swapFeeBips': swapAppFee?.bips ?? 0,
            'swapFeeRecipient': swapAppFee?.recipient,
          },
    );
  }

  static String? _optionalString(Object? value) => value is String && value.isNotEmpty ? value : null;

  static String? _endpoint(Object? value) {
    final endpoint = _optionalString(value);
    if (endpoint == null) return null;
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasAuthority || !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw FormatException('oneClickEndpoint is not a URL: $endpoint');
    }
    return endpoint;
  }

  static SwapAppFee? _swapAppFee(Object? bips, Object? recipient) {
    final fee = (bips as num?)?.toInt() ?? 0;
    final account = _optionalString(recipient);
    if (fee < 0) throw FormatException('swapFeeBips is negative: $fee');
    if (fee > 0 && account == null) throw const FormatException('swapFeeBips is set without a swapFeeRecipient');
    return fee > 0 ? (recipient: account!, bips: fee) : null;
  }

  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) {
    return RemoteConfigModel(
      enableTestButtons: json['enableTestButtons'] ?? defaults.enableTestButtons,
      enableKeystoneHardwareWallet: json['enableKeystoneHardwareWallet'] ?? defaults.enableKeystoneHardwareWallet,
      enableHighSecurity: json['enableHighSecurity'] ?? defaults.enableHighSecurity,
      enableRemoteNotifications: json['enableRemoteNotifications'] ?? defaults.enableRemoteNotifications,
      enableSwap: json['enableSwap'] ?? defaults.enableSwap,
      enableSwapAndroid: json['enableSwapAndroid'] ?? defaults.enableSwapAndroid,
      enableEncryptedAccount: json['enableEncryptedAccount'] ?? defaults.enableEncryptedAccount,
      enableMultisig: json['enableMultisig'] ?? defaults.enableMultisig,
      enableOneClickNearWarning: json['enableOneClickNearWarning'] ?? defaults.enableOneClickNearWarning,
      swapQuantusAssetId: _optionalString(json['swapQuantusAssetId']),
      geoNearAllowed: json['geoNearAllowed'] ?? defaults.geoNearAllowed,
      oneClickEndpoint: _endpoint(json['oneClickEndpoint']),
      nearPartnerJwt: _optionalString(json['near.partner.jwt']),
      swapAppFee: _swapAppFee(json['swapFeeBips'], json['swapFeeRecipient']),
    );
  }

  @override
  bool operator ==(Object other) => other is RemoteConfigModel && mapEquals(toCacheJson(), other.toCacheJson());

  @override
  int get hashCode => Object.hashAll(toCacheJson().values);
}
