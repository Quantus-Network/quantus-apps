import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:human_checksum/human_checksum.dart';

class HumanReadableChecksumService {
  static final HumanReadableChecksumService _instance = HumanReadableChecksumService._internal();
  factory HumanReadableChecksumService() => _instance;
  HumanReadableChecksumService._internal();

  List<String>? _cachedWordList;
  Isolate? _isolate;
  SendPort? _isolateSendPort;

  Future<void> initialize() async {
    if (_cachedWordList != null) return;

    // Load word list in main thread
    final wordList = await rootBundle.loadString('assets/text/crypto_checksum_bip39.txt');
    _cachedWordList = wordList.split('\n').where((word) => word.isNotEmpty).toList();

    if (_cachedWordList!.length != 2048) {
      throw Exception('Word list must contain exactly 2048 words');
    }

    // Start the isolate
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntry, [receivePort.sendPort, _cachedWordList]);
    _isolateSendPort = await receivePort.first as SendPort;
  }

  Future<String> getHumanReadableName(String address) async {
    if (_cachedWordList == null) {
      await initialize();
    }

    final responsePort = ReceivePort();
    _isolateSendPort!.send([address, responsePort.sendPort]);
    final result = await responsePort.first as String;
    responsePort.close();
    return result;
  }

  void dispose() {
    _isolate?.kill();
    _isolate = null;
    _isolateSendPort = null;
  }
}

void _isolateEntry(List<dynamic> args) async {
  final mainSendPort = args[0] as SendPort;
  final words = args[1] as List<String>;

  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    final address = message[0] as String;
    final replyTo = message[1] as SendPort;

    try {
      final humanChecksum = HumanChecksum(words);
      final result = humanChecksum.addressToChecksum(address).join('-');
      replyTo.send(result);
    } catch (e) {
      debugPrint('Error in checksum isolate: $e');
      replyTo.send('');
    }
  }
}
