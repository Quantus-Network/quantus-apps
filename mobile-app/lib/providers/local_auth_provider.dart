import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

class LocalAuthState {
  final bool isAuthenticated;
  final bool isAuthenticating;

  LocalAuthState({this.isAuthenticated = true, this.isAuthenticating = false});

  LocalAuthState copyWith({bool? isAuthenticated, bool? isAuthenticating}) {
    return LocalAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }
}

final localAuthServiceProvider = Provider((_) => LocalAuthService());

final localAuthProvider = StateNotifierProvider<LocalAuthController, LocalAuthState>((ref) {
  return LocalAuthController(ref.read(localAuthServiceProvider));
});

class LocalAuthController extends StateNotifier<LocalAuthState> {
  final LocalAuthService _localAuthService;

  LocalAuthController(this._localAuthService) : super(LocalAuthState());

  Future<void> authenticate() async {
    if (state.isAuthenticating) return;

    state = state.copyWith(isAuthenticating: true);

    final didAuthenticate = await _localAuthService.authenticate(
      localizedReason: 'Please authenticate to access your wallet',
    );

    state = state.copyWith(isAuthenticated: didAuthenticate, isAuthenticating: false);
  }

  void checkAuthentication() {
    if (_localAuthService.shouldRequireAuthentication()) {
      state = state.copyWith(isAuthenticated: false);
      // Trigger auth only if not already authenticating
      if (!state.isAuthenticating) {
        authenticate();
      }
    } else {
      state = state.copyWith(isAuthenticated: true, isAuthenticating: false);
    }
  }

  void lockApp() {
    // Only update pause time on true background; don't set authenticated=false immediately
    // to avoid UI flicker on transient pauses (FaceID, overlays)
    _localAuthService.updateLastPausedTime();
    // Do NOT set isAuthenticated=false here - let checkAuthentication on resume decide
  }
}
