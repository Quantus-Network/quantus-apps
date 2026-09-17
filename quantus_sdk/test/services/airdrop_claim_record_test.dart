import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a submitted claim round-trips through settings per wallet', () async {
    SharedPreferences.setMockInitialValues({});
    SettingsService().resetForTest();
    final settings = SettingsService();
    await settings.initialize();
    final record = AirdropClaimRecord(
      claimedAt: DateTime.utc(2026, 9, 16, 8, 30),
      rewardHundredths: 12180,
      claimAccount: 'qzpaidhere',
      accountName: 'Account 1',
    );

    expect(settings.getAirdropClaim(1), isNull);
    await settings.setAirdropClaim(1, record);
    final back = settings.getAirdropClaim(1)!;
    expect(back.claimedAt, record.claimedAt);
    expect(back.rewardHundredths, 12180);
    expect(back.claimAccount, 'qzpaidhere');
    expect(back.accountName, 'Account 1');
    expect(settings.getAirdropClaim(0), isNull);
  });

  test('the claimed label shows day and short month', () async {
    await initializeDateFormatting('en');
    expect(DatetimeFormattingService.formatDayMonth(DateTime(2026, 9, 16), 'en'), '16 Sep');
  });
}
