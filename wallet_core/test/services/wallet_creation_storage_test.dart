import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

const _phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _otherPhrase = 'legal winner thank year wave sausage worth useful legal winner thank yellow';
const _accountsKey = 'flutter.accounts_v5';
const _activeKey = 'flutter.active_display_account';
const _scheme = DilithiumSchemeExtension.current;

Account _root({int walletIndex = 0}) => Account(
  walletIndex: walletIndex,
  index: 0,
  name: 'Account 1',
  accountId: 'qzRoot',
  scheme: _scheme,
  derivationPath: HdWalletService.pathForIndex(0, _scheme),
);

/// Preferences whose chosen keys fail, the two ways a backend reports it.
class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.empty();

  final refused = <String>{};
  final throwing = <String>{};

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throwing.contains(key)) throw StateError('the disk is gone');
    if (refused.contains(key)) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  late _FailingStore store;
  late WalletCreationService service;

  Future<void> startApp() async {
    SharedPreferences.resetStatic();
    await settings.initialize();
  }

  setUp(() async {
    store = _FailingStore();
    SharedPreferencesStorePlatform.instance = store;
    FlutterSecureStorage.setMockInitialValues({});
    await startApp();
    service = WalletCreationService(settingsService: settings, accountsService: AccountsService());
  });

  Future<Account> create({int walletIndex = 0}) => service.createNewWallet(
    name: 'Account 1',
    mnemonic: _phrase,
    walletIndex: walletIndex,
    accountId: 'qzRoot',
    scheme: _scheme,
    derivationPath: HdWalletService.pathForIndex(0, _scheme),
  );

  final activationFailures = <String, void Function()>{
    'refused': () => store.refused.add(_activeKey),
    'throwing': () => store.throwing.add(_activeKey),
  };

  for (final MapEntry(key: how, value: failActivation) in activationFailures.entries) {
    group('when activating the stored root fails ($how)', () {
      test('import keeps the phrase, the account and the pending scan after a restart', () async {
        failActivation();

        await service.importWallet(mnemonic: _phrase, root: _root());
        await startApp();

        expect((await settings.getAccounts()).map((a) => a.accountId), ['qzRoot']);
        expect(await settings.getMnemonic(0), _phrase);
        expect(settings.pendingAccountScan(0), 'qzRoot');
        expect((await settings.getActiveAccount())?.account.accountId, 'qzRoot');
      });

      test('create keeps the phrase and the account after a restart', () async {
        failActivation();

        final created = await create();
        await startApp();

        expect(created.accountId, 'qzRoot');
        expect((await settings.getAccounts()).map((a) => a.accountId), ['qzRoot']);
        expect(await settings.getMnemonic(0), _phrase);
        expect((await settings.getActiveAccount())?.account.accountId, 'qzRoot');
      });
    });
  }

  group('when the root is not stored', () {
    test('import fails and leaves no phrase, account or pending scan', () async {
      store.throwing.add(_accountsKey);

      await expectLater(service.importWallet(mnemonic: _phrase, root: _root()), throwsStateError);

      expect(await settings.getAccounts(), isEmpty);
      expect(await settings.getMnemonic(0), isNull);
      expect(settings.pendingAccountScan(0), isNull);
    });

    test('import puts back a phrase the slot already held', () async {
      await settings.setMnemonic(_otherPhrase, 0);
      store.throwing.add(_accountsKey);

      await expectLater(service.importWallet(mnemonic: _phrase, root: _root()), throwsStateError);

      expect(await settings.getMnemonic(0), _otherPhrase);
    });

    test('create fails and leaves no phrase or account', () async {
      store.throwing.add(_accountsKey);

      await expectLater(create(), throwsStateError);

      expect(await settings.getAccounts(), isEmpty);
      expect(await settings.getMnemonic(0), isNull);
    });

    test('create puts back a phrase the slot already held', () async {
      await settings.setMnemonic(_otherPhrase, 0);
      store.throwing.add(_accountsKey);

      await expectLater(create(), throwsStateError);

      expect(await settings.getMnemonic(0), _otherPhrase);
    });
  });

  group('when the root was already stored by another wallet', () {
    setUp(() async {
      await settings.setMnemonic(_otherPhrase, 0);
      await settings.addAccount(_root());
    });

    test('import is refused and puts the new slot back', () async {
      await expectLater(service.importWallet(mnemonic: _phrase, root: _root(walletIndex: 1)), throwsException);

      expect(await settings.getMnemonic(0), _otherPhrase);
      expect(await settings.getMnemonic(1), isNull);
      expect(settings.pendingAccountScan(1), isNull);
    });

    test('create is refused and puts the new slot back', () async {
      await expectLater(create(walletIndex: 1), throwsException);

      expect(await settings.getMnemonic(0), _otherPhrase);
      expect(await settings.getMnemonic(1), isNull);
    });
  });
}
