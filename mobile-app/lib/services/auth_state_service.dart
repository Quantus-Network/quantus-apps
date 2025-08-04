import 'package:flutter/foundation.dart';

/// Singleton service that manages global authentication state
/// This allows the AuthenticationWrapper and route guards to share
/// the same auth state
class AuthStateService extends ChangeNotifier {
  static final AuthStateService _instance = AuthStateService._internal();
  factory AuthStateService() => _instance;
  AuthStateService._internal();

  bool _isAuthenticated = false;
  bool _hasInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get hasInitialized => _hasInitialized;

  void setAuthenticated(bool authenticated) {
    if (_isAuthenticated != authenticated) {
      _isAuthenticated = authenticated;
      _hasInitialized = true;
      notifyListeners();
    }
  }

  void setInitialized() {
    if (!_hasInitialized) {
      _hasInitialized = true;
      notifyListeners();
    }
  }

  void reset() {
    _isAuthenticated = false;
    _hasInitialized = false;
    notifyListeners();
  }
}
