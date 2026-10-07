import 'package:quantus_sdk/quantus_sdk.dart';

class AddressFormattingService {
  /// The one short form of an address or hash: six characters at each end.
  /// Shown next to its checkphrase wherever a wrong address would matter.
  static String formatAddress(String address) =>
      address.shortenedCryptoAddress(prefix: 6, ellipses: '.......', postFix: 6);

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
