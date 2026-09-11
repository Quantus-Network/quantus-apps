import 'dart:io';

import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('PairCompat');

/// Whether the installed node and miner speak the same miner-auth protocol.
enum PairCompatibility {
  /// Both advertise miner QUIC auth, or neither does.
  compatible,

  /// The node requires auth but the miner predates it. The miner exits on the unknown flags.
  minerTooOld,

  /// The miner expects auth but the node predates it. The handshake fails with no application protocol.
  nodeTooOld,
}

/// Probes the installed binaries the same way the official mining script does. A node whose help
/// lists `--miner-auth-token-file` and a miner whose help lists `--auth-token-file` and
/// `--tls-cert-sha256-file` are an auth pair. Mixing one of each fails at connection time with a
/// generic crash, so it is checked before the miner is started.
class PairCompatibilityService {
  /// Returns null if either probe fails to run, so a broken or wrong-architecture binary is left to
  /// the caller's existing checks instead of being misreported as a version mismatch.
  static Future<PairCompatibility?> check({required String nodeBinPath, required String minerBinPath}) async {
    try {
      final node = await Process.run(nodeBinPath, ['--help']);
      final miner = await Process.run(minerBinPath, ['serve', '--help']);
      if (node.exitCode != 0 || miner.exitCode != 0) {
        _log.w('Pair probe failed: node exit ${node.exitCode}, miner exit ${miner.exitCode}');
        return null;
      }
      final nodeHelp = '${node.stdout}${node.stderr}';
      final minerHelp = '${miner.stdout}${miner.stderr}';
      final nodeAuth = nodeHelp.contains('miner-auth-token-file');
      final minerAuth = minerHelp.contains('auth-token-file') && minerHelp.contains('tls-cert-sha256-file');
      if (nodeAuth == minerAuth) return PairCompatibility.compatible;
      return nodeAuth ? PairCompatibility.minerTooOld : PairCompatibility.nodeTooOld;
    } catch (e) {
      _log.w('Pair probe failed: $e');
      return null;
    }
  }
}
