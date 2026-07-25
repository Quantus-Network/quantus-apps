/// Shared timeouts for Patrol E2E tests.
///
/// Physical iOS devices and real network calls are slower and less predictable
/// than the simulator, so these are deliberately generous.
class PatrolTimeouts {
  PatrolTimeouts._();

  /// Time to let the app start up and the wallet gate settle onto a screen.
  static const Duration appLaunch = Duration(seconds: 60);

  /// Default time to wait for a widget to appear after an interaction.
  static const Duration visible = Duration(seconds: 30);

  /// Time to wait for operations that hit the network (e.g. account checksum,
  /// initial balance load on the home screen).
  static const Duration network = Duration(seconds: 45);

  /// Time to wait for extrinsic sign + broadcast after confirming a send.
  static const Duration transaction = Duration(seconds: 90);
}
