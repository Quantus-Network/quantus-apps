import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AuthenticationSettingsScreen extends StatefulWidget {
  const AuthenticationSettingsScreen({super.key});

  @override
  State<AuthenticationSettingsScreen> createState() =>
      _AuthenticationSettingsScreenState();
}

class _AuthenticationSettingsScreenState
    extends State<AuthenticationSettingsScreen> {
  final LocalAuthService _localAuthService = LocalAuthService();
  bool _isDeviceAuthEnabled = false;
  bool _isLoading = true;
  String _biometricDescription = 'Use Device Authentication';

  @override
  void initState() {
    super.initState();
    _loadAuthenticationSettings();
  }

  Future<void> _loadAuthenticationSettings() async {
    try {
      final isEnabled = _localAuthService.isLocalAuthEnabled();
      final isAvailable = await _localAuthService.isBiometricAvailable();
      final description = await _localAuthService.getBiometricDescription();

      if (mounted) {
        setState(() {
          _isDeviceAuthEnabled = isEnabled;
          _biometricDescription = isAvailable
              ? description
              : 'Biometric authentication not available';
          _isLoading = false;
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
          _showSnackBar(
            'Biometric authentication is not available on this device',
            isSuccess: false,
          );
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
         Positioned(
          top: context.containerHalfHeight * 0.8,
          right: -100,
          child: const Sphere(variant: 7, size: 311.489),
        ),
          Positioned(
          top: context.containerHalfHeight * 0.45,
          right: 10,
          child: const Sphere(variant: 2, size: 194),
        ),
      ],
      appBar: 'Authentication Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: context.isTablet ? 18 : 12,
            ),
            decoration: ShapeDecoration(
              color: context.themeColors.buttonGlass,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
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
                        style: context.themeText.detail?.copyWith(
                          color: context.themeColors.textMuted,
                        ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF16CECE),
                          ),
                        ),
                      )
                    : Switch(
                        value: _isDeviceAuthEnabled,
                        onChanged: _toggleAuthentication,
                        activeTrackColor: context.themeColors.buttonSuccess,
                        inactiveTrackColor: const Color(0xFFD9D9D9),
                        activeThumbColor: Colors.white,
                        inactiveThumbColor: Colors.white,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
