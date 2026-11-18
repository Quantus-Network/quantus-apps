import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/send/send_flow.dart';
import 'package:wallet_core/send/send_strategy.dart';

/// True while a send flow is on the navigation stack. Only one send flow can
/// be active at a time; incoming intents that would start or interrupt a send
/// are ignored while this is set. Only mutated by [startSendFlow].
final sendFlowActiveProvider = StateProvider<bool>((_) => false);

/// Single entry point for send flows: refuses to start a second flow, begins
/// the flow for [strategy] ([beginSendFlow]) from the tap that starts it, and
/// clears the in-flight flag when [screen]'s route leaves the stack — by pop,
/// replacement, or removal.
Future<void> startSendFlow(BuildContext context, {required SendStrategy strategy, required Widget screen}) async {
  final container = ProviderScope.containerOf(context);
  final sendFlow = container.read(sendFlowActiveProvider.notifier);
  if (sendFlow.state) {
    quantusPrint('startSendFlow ignored: a send flow is already active');
    return;
  }
  beginSendFlow(container.read, strategy);
  sendFlow.state = true;
  try {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  } finally {
    sendFlow.state = false;
  }
}
