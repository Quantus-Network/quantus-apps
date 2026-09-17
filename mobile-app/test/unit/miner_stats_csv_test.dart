import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

/// A Dirac-style export: quoted thousands, a "0.00" share, and a totals row.
const _diracExport = '''
ID,Total Rewards On Testnet,Total Mined Blocks,Sqrt Mined Blocks,Cumulative Mined,Cumulative Sqrt,% Reward Pool,Total Rewards On Mainnet,Total Reward Pool,Rewards Denominator
qza,877676606141581253,"89,778",300,"89,778",299.63,2.62%,65.39,2500,"11,456.25"
qzb,10000000000000,50,7,"89,828",306.63,0.06%,1.50,,
qzc,10000000000000,1,1,"89,829",307.63,0.01%,0.00,,
,,"89,829",,"179,658","12,721.96",,,,
''';

/// A Planck-style export: different address and blocks headers, an empty
/// reward, and a decimal block count.
const _planckExport = '''
Address,Total Rewards,Blocks mined,Cumulative Mined,Sqrt Mined,Cumulative Sqrt,% Reward Pool,Total Rewards On Mainnet,Total Reward Pool,Rewards Denominator
qzw,,"107,650.00","107,650",328.10,328.10,4.10%,102.53,2500,"8,000.13"
qzx,,1,"107,651",1.00,329.10,0.01%,,,
''';

void main() {
  test('reads address, blocks and mainnet reward whatever the export calls them', () {
    final dirac = parseMinerStatsCsv(_diracExport);
    expect(dirac.keys, ['qza', 'qzb', 'qzc']);
    expect(dirac['qza']!.blocks, 89778);
    expect(dirac['qza']!.rewardHundredths, 6539);
    expect(dirac['qzb']!.rewardHundredths, 150);

    final planck = parseMinerStatsCsv(_planckExport);
    expect(planck.keys, ['qzw', 'qzx']);
    expect(planck['qzw']!.blocks, 107650);
    expect(planck['qzw']!.rewardHundredths, 10253);
  });

  test('a zero or missing share becomes the 0.1 thank-you', () {
    expect(parseMinerStatsCsv(_diracExport)['qzc']!.rewardHundredths, 10);
    expect(parseMinerStatsCsv(_planckExport)['qzx']!.rewardHundredths, 10);
  });

  test('an export without a mainnet reward column is refused', () {
    expect(() => parseMinerStatsCsv('ID,Total Mined Blocks\nqza,5\n'), throwsA(isA<FormatException>()));
  });

  test('trimming keeps only address, blocks and reward, and reads back the same', () {
    final trimmed = trimmedMinerStatsCsv(parseMinerStatsCsv(_diracExport));
    expect(trimmed, 'address,blocks,reward\nqza,89778,65.39\nqzb,50,1.50\nqzc,1,0.10\n');

    final again = parseMinerStatsCsv(trimmed);
    expect(again.keys, ['qza', 'qzb', 'qzc']);
    expect(again['qza']!.blocks, 89778);
    expect(again['qza']!.rewardHundredths, 6539);
    expect(again['qzc']!.rewardHundredths, 10);
  });
}
