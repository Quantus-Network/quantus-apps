import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/services/auth_state_service.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

/// Lightweight authentication guard that reuses the shared auth state from
/// AuthenticationWrapper
/// This ensures consistent authentication behavior across all protected routes
class AuthGuard extends StatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  final AuthStateService _authStateService = AuthStateService();
  final LocalAuthService _localAuthService = LocalAuthService();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authStateService.addListener(_onAuthStateChanged);
    _checkAuthenticationNeeded();
  }

  @override
  void dispose() {
    _authStateService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkAuthenticationNeeded() async {
    // If we're not authenticated and not currently authenticating, prompt for
    // auth
    if (!_authStateService.isAuthenticated && !_isAuthenticating) {
      await _promptAuthentication();
    }
  }

  Future<void> _promptAuthentication() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    final didAuthenticate = await _localAuthService.authenticate(
      localizedReason: 'Please authenticate to access this feature',
    );

    setState(() {
      _isAuthenticating = false;
    });

    if (!didAuthenticate) {
      // Navigate back to safety if authentication fails
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } else {
      // Update the shared auth state so other guards know we're authenticated
      _authStateService.setAuthenticated(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we're authenticated, show the protected content
    if (_authStateService.isAuthenticated) {
      return widget.child;
    }

    // Otherwise show the authentication prompt
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
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _promptAuthentication,
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
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Fira Code',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
