import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

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
  String _biometricDescription = 'Device Authentication';

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

  Future<void> _toggleAuthentication(bool value) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (!value) {
        // Disabling authentication - no need for biometric verification
        _localAuthService.setLocalAuthEnabled(false);
        if (mounted) {
          setState(() {
            _isDeviceAuthEnabled = false;
            _isLoading = false;
          });
        }
        _showSnackBar('Device authentication disabled', isSuccess: true);
        return;
      }

      // Enabling authentication - require biometric verification first
      debugPrint('Starting authentication enablement process...');

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

      final availableBiometrics = await _localAuthService
          .getAvailableBiometrics();
      debugPrint('Available biometrics: $availableBiometrics');

      debugPrint('Attempting to authenticate...');
      final didAuthenticate = await _localAuthService.authenticate(
        localizedReason:
            'Authenticate to enable device authentication for your wallet',
        biometricOnly: false, // Allow fallback to device PIN if needed
        forSetup: true, // This is a setup flow, so bypass the enabled check
      );

      debugPrint('Authentication result: $didAuthenticate');

      if (didAuthenticate) {
        _localAuthService.setLocalAuthEnabled(true);
        if (mounted) {
          setState(() {
            _isDeviceAuthEnabled = true;
            _isLoading = false;
          });
        }
        _showSnackBar(
          'Device authentication enabled successfully',
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
          'Authentication failed. Device authentication not enabled.',
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
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WalletAppBar(title: 'Authentication Settings'),
              Padding(
                padding: const EdgeInsets.fromLTRB(25.0, 12.0, 25.0, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: const Color(0xFF313131),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Authentication',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoading ? 'Loading...' : _biometricDescription,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF16CECE),
                                ),
                              ),
                            )
                          : Switch(
                              value: _isDeviceAuthEnabled,
                              onChanged: _toggleAuthentication,
                              activeTrackColor: const Color(0xFF16CECE),
                              inactiveTrackColor: const Color(0xFFD9D9D9),
                              activeColor: Colors.white,
                              inactiveThumbColor: Colors.white,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
