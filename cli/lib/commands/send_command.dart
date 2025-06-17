import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class SendCommand extends Command<int> {
  SendCommand({required this.logger});

  @override
  String get description => 'Send tokens to a recipient (coming soon).';

  @override
  String get name => 'send';

  final Logger logger;

  @override
  Future<int> run() async {
    logger.info('This feature is coming soon!');
    return 0;
  }
}
