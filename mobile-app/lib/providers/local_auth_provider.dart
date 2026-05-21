import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

class LocalAuthState {
  final bool isAuthenticated;
  final bool isAuthenticating;
  final bool isVisuallyLocked;

  LocalAuthState({this.isAuthenticated = true, this.isAuthenticating = false, this.isVisuallyLocked = false});

  LocalAuthState copyWith({bool? isAuthenticated, bool? isAuthenticating, bool? isVisuallyLocked}) {
    return LocalAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isVisuallyLocked: isVisuallyLocked ?? this.isVisuallyLocked,
    );
  }
}

final localAuthServiceProvider = Provider((_) => LocalAuthService());

final localAuthProvider = StateNotifierProvider<LocalAuthController, LocalAuthState>((ref) {
  return LocalAuthController(ref.read(localAuthServiceProvider));
});

class LocalAuthController extends StateNotifier<LocalAuthState> {
  final LocalAuthService _localAuthService;

  static const _visualLockGrace = Duration(seconds: 5);
  Timer? _visualLockTimer;

  LocalAuthController(this._localAuthService) : super(LocalAuthState());

  @override
  void dispose() {
    _visualLockTimer?.cancel();
    super.dispose();
  }

  Future<void> authenticate() async {
    if (state.isAuthenticating) return;

    state = state.copyWith(isAuthenticating: true);

    final didAuthenticate = await _localAuthService.authenticate(
      localizedReason: 'Please authenticate to access your wallet',
    );

    state = state.copyWith(isAuthenticated: didAuthenticate, isAuthenticating: false, isVisuallyLocked: false);
  }

  Future<void> checkAuthentication() async {
    _cancelVisualLockTimer();
    if (await _localAuthService.shouldRequireAuthentication()) {
      final alreadyAuthenticating = state.isAuthenticating;
      state = state.copyWith(isAuthenticated: false);
      if (!alreadyAuthenticating) {
        authenticate();
      }
    } else {
      state = state.copyWith(isAuthenticated: true, isAuthenticating: false, isVisuallyLocked: false);
    }
  }

  Future<void> recordBackgroundTime() async {
    final didUpdate = await _localAuthService.updateLastPausedTime();
    if (!didUpdate) return;
    _cancelVisualLockTimer();
    _visualLockTimer = Timer(_visualLockGrace, () {
      if (!mounted) return;
      state = state.copyWith(isVisuallyLocked: true);
    });
  }

  void clearVisualLock() {
    _cancelVisualLockTimer();
    state = state.copyWith(isVisuallyLocked: false);
  }

  void _cancelVisualLockTimer() {
    _visualLockTimer?.cancel();
    _visualLockTimer = null;
  }
}
