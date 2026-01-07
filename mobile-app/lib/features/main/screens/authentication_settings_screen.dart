import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AuthConfigItem {
  final int value; // should be time in minutes
  final String label;

  AuthConfigItem({required this.value, required this.label});
}

class AuthenticationSettingsScreen extends StatefulWidget {
  const AuthenticationSettingsScreen({super.key});

  @override
  State<AuthenticationSettingsScreen> createState() => _AuthenticationSettingsScreenState();
}

class _AuthenticationSettingsScreenState extends State<AuthenticationSettingsScreen> {
  final LocalAuthService _localAuthService = LocalAuthService();
  final _authConfigList = [
    AuthConfigItem(value: 0, label: 'Immediately'),
    AuthConfigItem(value: 1, label: '1 minute'),
    AuthConfigItem(value: 5, label: '5 minutes'),
    AuthConfigItem(value: 15, label: '15 minutes'),
    AuthConfigItem(value: 30, label: '30 minutes'),
    AuthConfigItem(value: 60, label: '1 hour'),
  ];

  bool _isDeviceAuthEnabled = false;
  bool _isLoading = true;
  String _biometricDescription = 'Use Device Authentication';
  late int _authTimeout;

  @override
  void initState() {
    super.initState();
    _authTimeout = _localAuthService.getAuthTimeoutMinutes();
    _loadAuthenticationSettings();
  }

  Future<void> _loadAuthenticationSettings() async {
    try {
      final isEnabled = _localAuthService.isLocalAuthEnabled();
      final authTimeout = _localAuthService.getAuthTimeoutMinutes();
      final isAvailable = await _localAuthService.isBiometricAvailable();
      final description = await _localAuthService.getBiometricDescription();

      if (mounted) {
        setState(() {
          _isDeviceAuthEnabled = isEnabled;
          _biometricDescription = isAvailable ? description : 'Biometric authentication not available';
          _isLoading = false;
          _authTimeout = authTimeout;
        });
      }
    } catch (e) {
      debugPrint('Error loading authentication settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleAuthentication(bool enable) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // on enable, check if the device supports biometrics.
      if (enable) {
        final isAvailable = await _localAuthService.isBiometricAvailable();
        debugPrint('Biometric available: $isAvailable');

        if (!isAvailable) {
          debugPrint('Biometric authentication not available');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          _showSnackBar('Biometric authentication is not available on this device', isSuccess: false);
          return;
        }
      }

      debugPrint('Attempting to authenticate...');
      final didAuthenticate = await _localAuthService.authenticate(
        localizedReason:
            'Authenticate to ${enable ? 'enable' : 'disable'} device '
            'authentication for your wallet',
        biometricOnly: false, // Allow fallback to device PIN if needed
        forSetup: true, // This is a setup flow, so bypass the enabled check
      );

      debugPrint('Authentication result: $didAuthenticate');

      if (didAuthenticate) {
        _localAuthService.setLocalAuthEnabled(enable);
        if (mounted) {
          setState(() {
            _isDeviceAuthEnabled = enable;
            _isLoading = false;
          });
        }
        _showSnackBar(
          'Device authentication ${enable ? 'enabled' : 'disabled'} '
          'successfully',
          isSuccess: true,
        );
      } else {
        debugPrint('Authentication failed or was cancelled');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        _showSnackBar(
          'Authentication failed. Device authentication not '
          '${enable ? 'enabled' : 'disabled'}.',
          isSuccess: false,
        );
      }
    } catch (e) {
      debugPrint('Error in authentication toggle: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showSnackBar('Failed to toggle authentication: $e', isSuccess: false);
    }
  }

  void _setAuthTimeout(int timeoutDurationInMinutes) {
    _localAuthService.setAuthTimeoutMinutes(timeoutDurationInMinutes);
    setState(() {
      _authTimeout = timeoutDurationInMinutes;
    });
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      decorations: [
        Positioned(top: context.containerHalfHeight * 0.9, right: -100, child: const Sphere(variant: 7, size: 311.489)),
        Positioned(top: context.containerHalfHeight * 0.45, right: 10, child: const Sphere(variant: 2, size: 194)),
      ],
      appBar: WalletAppBar(title: 'Authentication Settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: context.isTablet ? 18 : 12),
            decoration: ShapeDecoration(
              color: context.themeColors.buttonGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/finger_print_icon.svg'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Authentication', style: context.themeText.largeTag),
                      const SizedBox(height: 4),
                      Text(
                        _isLoading ? 'Loading...' : _biometricDescription,
                        style: context.themeText.detail?.copyWith(color: context.themeColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _isLoading
                    ? SizedBox(
                        width: context.isTablet ? 28 : 20,
                        height: context.isTablet ? 28 : 20,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16CECE)),
                        ),
                      )
                    : CupertinoSwitch(
                        value: _isDeviceAuthEnabled,
                        onChanged: _toggleAuthentication,
                        activeTrackColor: context.themeColors.buttonSuccess,
                        inactiveTrackColor: context.themeColors.textMuted,
                        thumbColor: context.themeColors.buttonNeutral,
                      ),
              ],
            ),
          ),
          if (!_isLoading && _isDeviceAuthEnabled) ...[
            const SizedBox(height: 29),
            Text('Require Authentication', style: context.themeText.smallParagraph),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: ShapeDecoration(
                color: context.themeColors.buttonGlass,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Column(
                children: _authConfigList.map((item) {
                  final isFirstItem = item.value == 0;
                  final isLastItem = item.value == 60;

                  final double topPadding = isFirstItem ? 0 : 15;
                  final double bottomPadding = isLastItem ? 0 : 15;

                  final border = BorderSide(color: Colors.black.useOpacity(0.65), width: 0.6);
                  final topBorder = isFirstItem ? BorderSide.none : border;
                  final bottomBorder = isLastItem ? BorderSide.none : border;

                  return InkWell(
                    onTap: () {
                      _setAuthTimeout(item.value);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(top: topBorder, bottom: bottomBorder),
                      ),
                      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding, left: 18, right: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.label, style: context.themeText.smallParagraph),
                          if (item.value == _authTimeout)
                            Icon(Icons.check_circle, color: context.themeColors.buttonSuccess, size: 16),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
