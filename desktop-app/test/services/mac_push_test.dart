import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/mac_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const push = ChannelMacPush();

  /// Answers the app's calls as the Mac would, and records them.
  List<String> serve(Object? Function(MethodCall call) answer) {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(ChannelMacPush.channel, (call) async {
      calls.add(call.method);
      return answer(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(ChannelMacPush.channel, null));
    return calls;
  }

  /// A click the Mac hands to the app.
  Future<void> macClicks(String payload) => messenger.handlePlatformMessage(
    ChannelMacPush.channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall('click', payload)),
    (_) {},
  );

  test('reads which of Apple\'s push services the build was signed for, or that it was for neither', () async {
    String? signedFor = 'production';
    final calls = serve((_) => signedFor);

    expect(await push.environment(), 'production');
    signedFor = null;
    expect(await push.environment(), isNull);
    expect(calls, ['environment', 'environment']);
  });

  test('asks the Mac for its push token', () async {
    final calls = serve((_) => 'a1b2c3');

    expect(await push.requestToken(), 'a1b2c3');
    expect(calls, ['token']);
  });

  test('a token the Mac cannot get fails', () async {
    serve((_) => throw PlatformException(code: 'token-failed', message: 'no connection to Apple'));

    await expectLater(push.requestToken(), throwsA(isA<PlatformException>()));
  });

  test('a Mac that answers with no token fails', () async {
    serve((_) => null);

    await expectLater(push.requestToken(), throwsStateError);
  });

  test('hands over the click that launched the app, then every click after it', () async {
    final calls = serve((call) => call.method == 'takeLaunchClick' ? '{"accountId":"qzMain"}' : null);
    final clicks = <String>[];

    await push.listenToClicks(clicks.add);
    await macClicks('{"accountId":"qzSavings"}');

    expect(calls, ['takeLaunchClick']);
    expect(clicks, ['{"accountId":"qzMain"}', '{"accountId":"qzSavings"}']);
  });

  test('hands over nothing at the start when no click launched the app', () async {
    serve((_) => null);
    final clicks = <String>[];

    await push.listenToClicks(clicks.add);

    expect(clicks, isEmpty);
  });
}
