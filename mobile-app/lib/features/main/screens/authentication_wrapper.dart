import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_initializer.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper>
    with WidgetsBindingObserver {
  final LocalAuthService _localAuthService = LocalAuthService();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthentication();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAuthentication();
    }
  }

  Future<void> _checkAuthentication() async {
    // Prevent multiple auth checks at the same time
    if (_isAuthenticating) return;

    final shouldAuth = await _localAuthService.shouldRequireAuthentication();

    if (shouldAuth) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
      _authenticate();
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    if (mounted) {
      setState(() {
        _isAuthenticating = true;
      });
    }

    final didAuthenticate = await _localAuthService.authenticate(
      localizedReason: 'Please authenticate to access your wallet',
    );

    if (mounted) {
      setState(() {
        _isAuthenticated = didAuthenticate;
        _isAuthenticating = false;
      });
    }

    if (!didAuthenticate) {
      // Handle failed authentication, maybe close the app or show an error.
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      }
      // On iOS, we can't programmatically close the app,
      // so we'll just stay on the lock screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated ? const WalletInitializer() : _buildLockScreen();
  }

  Widget _buildLockScreen() {
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Authentication Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Fira Code',
                ),
              ),
              const SizedBox(height: 30),
              if (_isAuthenticating)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
              else
                ElevatedButton(
                  onPressed: _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16CECE),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Authenticate',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Fira Code',
                      fontSize: 16,
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
