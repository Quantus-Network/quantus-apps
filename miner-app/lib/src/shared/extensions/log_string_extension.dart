extension LogStringExtension on String {
  bool get isNodeError {
    final lower = toLowerCase();
    return lower.contains('error') ||
        lower.contains('panic') ||
        lower.contains('fatal') ||
        lower.contains('critical') ||
        lower.contains('failed');
  }

  bool get isMinerError {
    return contains('ERROR');
  }
}
