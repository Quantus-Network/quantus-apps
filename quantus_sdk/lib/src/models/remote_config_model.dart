class RemoteConfigModel {
  final bool enableTestButtons;
  final bool enableKeystoneHardwareWallet;
  final bool enableHighSecurity;
  final bool enableRemoteNotifications;
  final bool enableSwap;
  final bool enableMultisig;

  const RemoteConfigModel({
    required this.enableTestButtons,
    required this.enableKeystoneHardwareWallet,
    required this.enableHighSecurity,
    required this.enableRemoteNotifications,
    required this.enableSwap,
    required this.enableMultisig,
  });

  R match<R>({
    required R Function(
      bool enableTestButtons,
      bool enableKeystoneHardwareWallet,
      bool enableHighSecurity,
      bool enableRemoteNotifications,
      bool enableSwap,
      bool enableMultisig,
    )
    fn,
  }) {
    return fn(
      enableTestButtons,
      enableKeystoneHardwareWallet,
      enableHighSecurity,
      enableRemoteNotifications,
      enableSwap,
      enableMultisig,
    );
  }

  static const RemoteConfigModel defaults = RemoteConfigModel(
    enableTestButtons: false,
    enableKeystoneHardwareWallet: false,
    enableHighSecurity: true,
    enableRemoteNotifications: true,
    enableSwap: true,
    enableMultisig: false,
  );

  Map<String, dynamic> toCacheJson() {
    return match(
      fn: (test, keystone, security, notifications, swap, multisig) => {
        'enableTestButtons': test,
        'enableKeystoneHardwareWallet': keystone,
        'enableHighSecurity': security,
        'enableRemoteNotifications': notifications,
        'enableSwap': swap,
        'enableMultisig': multisig,
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
      enableMultisig: json['enableMultisig'] ?? defaults.enableMultisig,
    );
  }

  bool compare(RemoteConfigModel other) {
    return match(
      fn:
          (
            enableTestButtons,
            enableKeystoneHardwareWallet,
            enableHighSecurity,
            enableRemoteNotifications,
            enableSwap,
            enableMultisig,
          ) {
            return other.match(
              fn:
                  (
                    otherEnableTestButtons,
                    otherEnableKeystoneHardwareWallet,
                    otherEnableHighSecurity,
                    otherEnableRemoteNotifications,
                    otherEnableSwap,
                    otherEnableMultisig,
                  ) {
                    return enableTestButtons == otherEnableTestButtons &&
                        enableKeystoneHardwareWallet == otherEnableKeystoneHardwareWallet &&
                        enableHighSecurity == otherEnableHighSecurity &&
                        enableRemoteNotifications == otherEnableRemoteNotifications &&
                        enableSwap == otherEnableSwap &&
                        enableMultisig == otherEnableMultisig;
                  },
            );
          },
    );
  }
}
