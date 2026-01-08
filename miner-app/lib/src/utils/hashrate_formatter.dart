class HashrateFormatter {
  static String format(double hashrate) {
    if (hashrate >= 1E12) {
      return '${(hashrate / 1E12).toStringAsFixed(2)} TH/s';
    } else if (hashrate >= 1E9) {
      return '${(hashrate / 1E9).toStringAsFixed(2)} GH/s';
    } else if (hashrate >= 1E6) {
      return '${(hashrate / 1E6).toStringAsFixed(2)} MH/s';
    } else if (hashrate >= 1E3) {
      return '${(hashrate / 1E3).toStringAsFixed(2)} KH/s';
    } else {
      return '${hashrate.toStringAsFixed(2)} H/s';
    }
  }
}
