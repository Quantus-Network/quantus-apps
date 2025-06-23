import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class SendCommand extends Command<int> {
  SendCommand({required this.logger}) {
    argParser
      ..addOption('recipient', abbr: 'r', help: 'The recipient address.', mandatory: true)
      ..addOption('amount', abbr: 'a', help: 'The amount of tokens to send.', mandatory: true);
  }

  @override
  String get description => 'Send tokens to a recipient.';

  @override
  String get name => 'send';

  final Logger logger;

  @override
  Future<int> run() async {
    final recipient = argResults?['recipient'] as String;
    final amount = argResults?['amount'] as String;
    logger.info('Received request to send $amount tokens to $recipient.');
    logger.info('This feature is coming soon!');
    return 0;
  }
}
