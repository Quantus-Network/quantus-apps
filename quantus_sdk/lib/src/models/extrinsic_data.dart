import 'package:flutter/foundation.dart';

class ExtrinsicData {
  Uint8List payload;
  int blockNumber;
  String blockHash;
  int nonce;
  ExtrinsicData({
    required this.payload,
    required this.blockHash,
    required this.blockNumber,
    required this.nonce,
  });
}
