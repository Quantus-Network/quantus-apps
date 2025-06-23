import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class ResonanceCliRunner extends CommandRunner<int> {
  ResonanceCliRunner({required Logger logger, required List<Command<int>> commands})
    : _logger = logger,
      super('resonance', 'A CLI for interacting with the Resonance Network.') {
    commands.forEach(addCommand);
  }

  final Logger _logger;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await super.run(args) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } catch (error, stackTrace) {
      _logger
        ..err('$error')
        ..err('$stackTrace');
      return ExitCode.software.code;
    }
  }
}
