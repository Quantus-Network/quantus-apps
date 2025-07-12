import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/services/wallet_state_manager.dart';
import 'wallet_state_manager_test.mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([SettingsService, SubstrateService, ChainHistoryService])
void main() {
  group('WalletStateManager', () {
    late WalletStateManager manager;
    late MockSettingsService mockSettings;
    late MockSubstrateService mockSubstrate;
    late MockChainHistoryService mockHistory;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      mockSettings = MockSettingsService();
      mockSubstrate = MockSubstrateService();
      mockHistory = MockChainHistoryService();
      manager = WalletStateManager(
        settingsService: mockSettings,
        substrateService: mockSubstrate,
        chainHistoryService: mockHistory,
      );
      provideDummy<BigInt>(BigInt.zero);
    });

    test('loadInitialData updates balance and transactions', () async {
      when(mockSettings.getAccountId()).thenAnswer((_) async => 'test_id');
      when(mockSubstrate.queryBalance('test_id')).thenAnswer((_) async => BigInt.from(1000));
      when(
        mockHistory.fetchAllTransactionTypes(accountId: 'test_id', limit: 20, offset: 0),
      ).thenAnswer((_) async => SortedTransactionsList(reversibleTransfers: [], otherTransfers: []));

      await manager.loadInitialData();

      expect(manager.currentBalance, BigInt.from(1000));
      expect(manager.transactions, isEmpty);
    });

    test('addPendingSend updates balance and adds tx optimistically', () async {
      manager.updateBalance(BigInt.from(1000));
      await manager.addPendingSend(amount: BigInt.from(200), to: 'recipient');

      expect(manager.currentBalance, BigInt.from(800));
      expect(manager.transactions.length, 1);
      expect(manager.transactions[0].amount, BigInt.from(200));
    });

    // Add more tests for loadMore, refresh, errors, etc.
  });
}
