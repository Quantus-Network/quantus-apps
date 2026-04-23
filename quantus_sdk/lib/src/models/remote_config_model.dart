class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableSwap;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableSwap,
  });

  R match<R>({
    required R Function(
      bool enableTestButtons,
      bool enableKeystoneHardwareWallet,
      bool enableHighSecurity,
      bool enableRemoteNotifications,
      bool enableSwap,
    )
    fn,
  }) {
    return fn(
      enableTestButtons,
      enableKeystoneHardwareWallet,
      enableHighSecurity,
      enableRemoteNotifications,
      enableSwap,
    );
  }

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: false,
    enableHighSecurity: true,
    enableRemoteNotifications: true,
    enableSwap: true,
  );

  Map<String, dynamic> toCacheJson() {
    return match(
      fn: (test, keystone, security, notifications, swap) => {
        'enableTestButtons': test,
        'enableKeystoneHardwareWallet': keystone,
        'enableHighSecurity': security,
        'enableRemoteNotifications': notifications,
        'enableSwap': swap,
      },
    );
  }

  factory RemoteConfigModel.fromJson(Map<String, dynamic> json) {
    return RemoteConfigModel(
      enableTestButtons: json['enableTestButtons'] ?? defaults.enableTestButtons,
      enableKeystoneHardwareWallet: json['enableKeystoneHardwareWallet'] ?? defaults.enableKeystoneHardwareWallet,
      enableHighSecurity: json['enableHighSecurity'] ?? defaults.enableHighSecurity,
      enableRemoteNotifications: json['enableRemoteNotifications'] ?? defaults.enableRemoteNotifications,
      enableSwap: json['enableSwap'] ?? defaults.enableSwap,
    );
  }

  bool compare(RemoteConfigModel other) {
    return match(
      fn: (enableTestButtons, enableKeystoneHardwareWallet, enableHighSecurity, enableRemoteNotifications, enableSwap) {
        return other.match(
          fn:
              (
                otherEnableTestButtons,
                otherEnableKeystoneHardwareWallet,
                otherEnableHighSecurity,
                otherEnableRemoteNotifications,
                otherEnableSwap,
              ) {
                return enableTestButtons == otherEnableTestButtons &&
                    enableKeystoneHardwareWallet == otherEnableKeystoneHardwareWallet &&
                    enableHighSecurity == otherEnableHighSecurity &&
                    enableRemoteNotifications == otherEnableRemoteNotifications &&
                    enableSwap == otherEnableSwap;
              },
        );
      },
    );
  }
}
