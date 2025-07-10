import 'package:quantus_sdk/quantus_sdk.dart';

class AddressFormattingService {
  static String formatAddress(String address, {int prefix = 4, String ellipses = '...', int postFix = 4}) {
    return address.shortenedCryptoAddress(prefix: prefix, ellipses: ellipses, postFix: postFix);
  }
}
