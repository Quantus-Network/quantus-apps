class HashrateFormatter {
  static String format(double hashrate) {
    if (hashrate >= 10E12) {
      return '${(hashrate / 10E12).toStringAsFixed(2)} TH/s';
    } else if (hashrate >= 10E9) {
      return '${(hashrate / 10E9).toStringAsFixed(2)} GH/s';
    } else if (hashrate >= 10E6) {
      return '${(hashrate / 10E6).toStringAsFixed(2)} MH/s';
    } else if (hashrate >= 10E3) {
      return '${(hashrate / 10E3).toStringAsFixed(2)} KH/s';
    } else {
      return '${hashrate.toStringAsFixed(2)} H/s';
    }
  }
}
