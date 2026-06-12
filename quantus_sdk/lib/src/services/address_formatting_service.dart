import 'package:quantus_sdk/quantus_sdk.dart';

class AddressFormattingService {
  static String formatAddress(String address, {int prefix = 6, String ellipses = '...', int postFix = 6}) {
    return address.shortenedCryptoAddress(prefix: prefix, ellipses: ellipses, postFix: postFix);
  }

  /// Short address style used on activity transaction detail rows.
  static String formatActivityDetailAddress(String address) =>
      formatAddress(address, prefix: 7, ellipses: '.......', postFix: 6);

  /// Short extrinsic hash style used on activity transaction detail rows.
  static String formatActivityDetailExtrinsicHash(String hash) =>
      formatAddress(hash, prefix: 6, ellipses: '...', postFix: 4);

  static List<String> splitIntoChunks(String text, {int chunkSize = 5}) {
    if (chunkSize <= 0) {
      throw ArgumentError('Chunk size must be a positive integer.');
    }
    if (text.isEmpty) {
      return [];
    }

    List<String> chunks = [];
    for (int i = 0; i < text.length; i += chunkSize) {
      int endIndex = i + chunkSize;
      if (endIndex > text.length) {
        endIndex = text.length;
      }
      chunks.add(text.substring(i, endIndex));
    }
    return chunks;
  }
}
