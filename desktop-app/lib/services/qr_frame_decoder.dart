import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// Reads a QR code from a frame's brightness bytes, or returns null.
typedef QrLumaDecoder = String? Function(Uint8List luma, int width, int height);

/// The decoder failed in a way a bad frame should not cause.
class QrDecodeFailure implements Exception {
  const QrDecodeFailure(this.detail);

  final String detail;

  @override
  String toString() => 'QrDecodeFailure($detail)';
}

/// The text of the QR code in a frame of [width] by [height] brightness bytes.
/// Null when the frame holds no readable code, or only one part of a
/// multi-part code.
String? decodeQrLuma(Uint8List luma, int width, int height) {
  if (width <= 0 || height <= 0 || luma.length != width * height) return null;
  try {
    return textOfQrResult(QRCodeReader().decode(BinaryBitmap(HybridBinarizer(_LumaSource(luma, width, height)))));
  } on ReaderException {
    return null;
  } on ArgumentError {
    return null;
  } on UnsupportedError {
    return null;
  }
}

/// The text of [result], unless it is one part of a multi-part code, whose
/// text alone is not the whole message.
String? textOfQrResult(Result result) =>
    result.resultMetadata.containsKey(ResultMetadataType.structuredAppendSequence) ? null : result.text;

class _LumaSource extends LuminanceSource {
  _LumaSource(Uint8List luma, int width, int height) : _bytes = Int8List.sublistView(luma), super(width, height);

  final Int8List _bytes;

  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) throw ArgumentError('Row $y is outside the frame.');
    final out = row != null && row.length >= width ? row : Int8List(width);
    out.setRange(0, width, _bytes, y * width);
    return out;
  }

  @override
  Int8List getMatrix() => _bytes;
}

/// Decodes frames in a worker isolate, one at a time, so a frame built to stall
/// the decoder cannot freeze the window: a decode past [limit] is killed and
/// counts as no code.
class QrFrameDecoder {
  QrFrameDecoder({this.limit = const Duration(seconds: 2), QrLumaDecoder decoder = decodeQrLuma}) : _decoder = decoder;

  final Duration limit;
  final QrLumaDecoder _decoder;

  /// Ends the decode in flight with no code.
  void Function()? _abandon;
  bool _isClosed = false;

  /// The text of the QR code in the frame, or null. Throws [QrDecodeFailure]
  /// when the decoder itself breaks, and [StateError] when called while
  /// another decode runs or after [close].
  Future<String?> decode(Uint8List luma, int width, int height) async {
    if (_isClosed) throw StateError('The decoder is closed.');
    if (_abandon != null) throw StateError('One frame is decoded at a time.');

    final port = ReceivePort();
    final result = Completer<String?>();
    void abandon() {
      if (!result.isCompleted) result.complete(null);
    }

    _abandon = abandon;
    port.listen((message) {
      if (result.isCompleted) return;
      switch (message) {
        case _Decoded(:final text):
          result.complete(text);
        case [final error, _]:
          result.completeError(QrDecodeFailure('$error'));
        default:
          result.completeError(const QrDecodeFailure('The worker exited without an answer.'));
      }
    });

    Isolate? worker;
    Timer? timer;
    try {
      worker = await Isolate.spawn(
        _decodeInWorker,
        _Job(port.sendPort, TransferableTypedData.fromList([luma]), width, height, _decoder),
        onError: port.sendPort,
        onExit: port.sendPort,
      );
      timer = Timer(limit, abandon);
      return await result.future;
    } finally {
      timer?.cancel();
      worker?.kill(priority: Isolate.immediate);
      port.close();
      _abandon = null;
    }
  }

  /// Ends any decode in flight. The decoder cannot be used after this.
  void close() {
    _isClosed = true;
    _abandon?.call();
  }
}

class _Job {
  const _Job(this.answer, this.luma, this.width, this.height, this.decoder);

  final SendPort answer;
  final TransferableTypedData luma;
  final int width;
  final int height;
  final QrLumaDecoder decoder;
}

class _Decoded {
  const _Decoded(this.text);

  final String? text;
}

void _decodeInWorker(_Job job) {
  final luma = job.luma.materialize().asUint8List();
  job.answer.send(_Decoded(job.decoder(luma, job.width, job.height)));
}
