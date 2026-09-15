import 'dart:convert';
import 'dart:math';

/// Thank-you floor: a miner whose share rounds to nothing still gets 0.1.
const int minimumRewardHundredths = 10;

/// One miner's row in a chain's rewards table.
class MinerReward {
  final int blocks;
  final int rewardHundredths;

  const MinerReward({required this.blocks, required this.rewardHundredths});
}

/// Address → blocks and mainnet reward from a "Miner Stats" export or its
/// trimmed form. The exports name their columns differently, so each is found
/// by keyword; the trailing totals row has no address and is dropped.
Map<String, MinerReward> parseMinerStatsCsv(String csv) {
  final lines = const LineSplitter().convert(csv).where((l) => l.trim().isNotEmpty).toList();
  final header = _fields(lines.first).map((h) => h.toLowerCase()).toList();
  int column(String what, bool Function(String) matches) {
    final i = header.indexWhere(matches);
    if (i == -1) throw FormatException('Rewards table has no $what column: $header');
    return i;
  }

  final address = column('address', (h) => h == 'id' || h == 'address');
  final blocks = column(
    'blocks',
    (h) =>
        h == 'blocks' ||
        h.contains('mined') && h.contains('blocks') && !h.contains('sqrt') && !h.contains('cumulative'),
  );
  final reward = column('mainnet reward', (h) => h == 'reward' || h == 'total rewards on mainnet');

  final table = <String, MinerReward>{};
  for (final line in lines.skip(1)) {
    final fields = _fields(line);
    if (fields[address].isEmpty) continue;
    table[fields[address]] = MinerReward(
      blocks: _number(fields[blocks]).toInt(),
      rewardHundredths: max(minimumRewardHundredths, (_number(fields[reward]) * 100).round()),
    );
  }
  return table;
}

/// The table as `address,blocks,reward`, one miner per row.
String trimmedMinerStatsCsv(Map<String, MinerReward> table) => [
  'address,blocks,reward',
  for (final e in table.entries) '${e.key},${e.value.blocks},${(e.value.rewardHundredths / 100).toStringAsFixed(2)}',
  '',
].join('\n');

double _number(String field) => field.isEmpty ? 0 : double.parse(field.replaceAll(',', ''));

/// Splits one CSV line, honouring double-quoted fields.
List<String> _fields(String line) {
  final fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (final char in line.runes.map(String.fromCharCode)) {
    if (char == '"') {
      quoted = !quoted;
    } else if (char == ',' && !quoted) {
      fields.add(field.toString().trim());
      field.clear();
    } else {
      field.write(char);
    }
  }
  fields.add(field.toString().trim());
  return fields;
}
