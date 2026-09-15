// Trims the "Miner Stats" exports in assets/testnet_data down to the three
// columns the wallet reads (address, blocks, reward) and drops the totals row.
// Run from mobile-app after dropping in fresh exports:
//   dart run tool/trim_miner_stats.dart
import 'dart:io';

import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

void main() {
  final exports = Directory('assets/testnet_data').listSync().whereType<File>().where((f) => f.path.endsWith('.csv'));
  for (final file in exports) {
    final table = parseMinerStatsCsv(file.readAsStringSync());
    file.writeAsStringSync(trimmedMinerStatsCsv(table));
    stdout.writeln('${file.path}: ${table.length} miners');
  }
}
