import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

bool get _apple => defaultTargetPlatform == TargetPlatform.iOS;

/// What this platform calls the phone and the lock on its screen.
String get deviceName => _apple ? 'iPhone' : 'phone';
String get screenLockName => _apple ? 'passcode' : 'screen lock';

/// What a device that can enforce no [SealPolicy] is told, under its heading.
String get lockRequiredTitle => 'Set a $screenLockName first';
String get lockRequiredMessage => _apple
    ? 'Turn on a passcode in Settings, and Face ID if this iPhone has it, then come back. The signing key is kept '
          'only behind one of them.'
    : 'Set a screen lock in Settings, and a fingerprint if this phone reads one, then come back. The signing key is '
          'kept only behind one of them, and on Android 10 or older only behind the fingerprint.';

String get notRecognisedMessage => _apple
    ? 'This iPhone did not recognise you. If Face ID is locked, lock the phone and unlock it with your passcode. If '
          'it is turned off for this app, allow it in Settings.'
    : 'This phone did not recognise you. If it has locked biometrics, lock the phone and unlock it with your screen '
          'lock.';

extension SealPolicyWording on SealPolicy {
  /// What the device asks for before each use of the key, as it reads inside
  /// a sentence.
  String get credential => switch (this) {
    SealPolicy.biometry => _apple ? 'Face ID' : 'biometrics',
    SealPolicy.devicePasscode => 'your $screenLockName',
  };

  /// [credential] at the start of a sentence.
  String get credentialTitle => credential[0].toUpperCase() + credential.substring(1);
}
