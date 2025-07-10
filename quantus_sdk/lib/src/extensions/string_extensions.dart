extension AddressShortenerString on String {
  String shortenedCryptoAddress({int prefix = 4, String ellipses = '...', int postFix = 4}) {
    if (length <= prefix + postFix) {
      return this;
    }

    return '${substring(0, prefix)}$ellipses${substring(length - postFix)}';
  }
}
