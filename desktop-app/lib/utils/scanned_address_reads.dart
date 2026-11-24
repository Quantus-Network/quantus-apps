/// What one code read from the camera came to.
sealed class ScannedRead {
  const ScannedRead();
}

/// A valid address, not read enough times yet.
final class ReadPending extends ScannedRead {
  const ReadPending();
}

/// The same address, read enough times in a row to be shown for confirming.
final class ReadConfirmed extends ScannedRead {
  const ReadConfirmed(this.address);

  final String address;
}

final class ReadNotAnAddress extends ScannedRead {
  const ReadNotAnAddress();
}

final class ReadAlreadyInApp extends ScannedRead {
  const ReadAlreadyInApp();
}

/// Counts the codes read from separate frames. An address counts once it has
/// been read [needed] times in a row, so a single misread frame cannot become
/// an account; anything else read in between starts the count again.
class ScannedAddressReads {
  ScannedAddressReads({required bool Function(String) isValidAddress, required bool Function(String) isInApp})
    : _isValidAddress = isValidAddress,
      _isInApp = isInApp;

  static const needed = 3;

  final bool Function(String) _isValidAddress;
  final bool Function(String) _isInApp;

  String? _candidate;
  int _count = 0;

  ScannedRead add(String text) {
    final address = text.trim();
    if (!_isValidAddress(address)) {
      reset();
      return const ReadNotAnAddress();
    }
    if (_isInApp(address)) {
      reset();
      return const ReadAlreadyInApp();
    }
    _count = address == _candidate ? _count + 1 : 1;
    _candidate = address;
    if (_count < needed) return const ReadPending();
    reset();
    return ReadConfirmed(address);
  }

  void reset() {
    _candidate = null;
    _count = 0;
  }
}
