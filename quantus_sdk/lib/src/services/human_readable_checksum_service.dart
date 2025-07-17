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
  final _checkPhraseCache = <String, String>{};
  Completer<void>? _isolateReadyCompleter;

  Future<void> initialize() async {
    if (_cachedWordList != null && _isolateSendPort != null && (_isolateReadyCompleter?.isCompleted ?? false)) {
      return;
    }

    if (_isolateReadyCompleter != null && !_isolateReadyCompleter!.isCompleted) {
      await _isolateReadyCompleter!.future;
      return;
    }

    _isolateReadyCompleter = Completer<void>();

    try {
      if (_cachedWordList == null) {
        final wordList = await rootBundle.loadString('assets/text/crypto_checksum_bip39.txt');
        _cachedWordList = wordList.split('\n').where((word) => word.isNotEmpty).toList();

        if (_cachedWordList!.length != 2048) {
          _isolateReadyCompleter!.completeError(Exception('Word list must contain exactly 2048 words'));
          throw Exception('Word list must contain exactly 2048 words');
        }
      }

      if (_isolateSendPort == null) {
        final receivePort = ReceivePort();
        _isolate = await Isolate.spawn(_isolateEntry, [receivePort.sendPort, _cachedWordList!]);
        _isolateSendPort = await receivePort.first as SendPort;
      }

      _isolateReadyCompleter!.complete();
    } catch (e, s) {
      debugPrint('Error during checksum isolate initialization: $e');
      debugPrint('Initialization error stack: $s');
      if (!(_isolateReadyCompleter?.isCompleted ?? false)) {
        _isolateReadyCompleter!.completeError(e);
      }
      _isolate?.kill();
      _isolate = null;
      _isolateSendPort = null;
      _cachedWordList = null;
      rethrow;
    }
  }

  Future<String> getHumanReadableName(String address, {upperCase = true}) async {
    try {
      final key = address + (upperCase ? '#U' : '');
      if (_checkPhraseCache.containsKey(key)) {
        return _checkPhraseCache[key]!;
      }

      if (!(_isolateReadyCompleter?.isCompleted ?? false)) {
        await initialize();
      }

      if (_isolateSendPort == null) {
        debugPrint('Error: _isolateSendPort is null after successful initialization wait.');
        return '';
      }

      final responsePort = ReceivePort();
      _isolateSendPort!.send([address, responsePort.sendPort]);
      final result = await responsePort.first as String?;
      responsePort.close();

      var finalResult = result ?? '';

      if (upperCase) {
        finalResult = finalResult
            .split('-')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .toList()
            .join('-');
      }
      _checkPhraseCache[key] = finalResult;
      return finalResult;
    } catch (e, s) {
      debugPrint('Error in getHumanReadableName for address $address: $e');
      debugPrint('Lookup error stack: $s');
      _checkPhraseCache.remove(address);
      return '';
    }
  }

  void dispose() {
    debugPrint('Disposing HumanReadableChecksumService...');
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolateSendPort = null;
    _cachedWordList = null;
    _checkPhraseCache.clear();
    if (!(_isolateReadyCompleter?.isCompleted ?? false)) {
      _isolateReadyCompleter?.completeError('HumanReadableChecksumService disposed');
    }
    _isolateReadyCompleter = null;
    debugPrint('HumanReadableChecksumService disposed.');
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
    } catch (e, s) {
      debugPrint('Error in checksum isolate processing address $address: $e');
      debugPrint('Isolate error stack: $s');
      replyTo.send('');
    }
  }
  debugPrint('Checksum isolate message stream closed.');
}
