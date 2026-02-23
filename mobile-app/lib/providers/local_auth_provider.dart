import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

class LocalAuthState {
  final bool isAuthenticated;
  final bool isAuthenticating;

  LocalAuthState({this.isAuthenticated = false, this.isAuthenticating = false});

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
      authenticate();
    } else {
      state = state.copyWith(isAuthenticated: true);
    }
  }

  void lockApp() {
    _localAuthService.updateLastPausedTime();
    state = state.copyWith(isAuthenticated: false);
  }
}
