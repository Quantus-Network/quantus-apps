import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await QuantusSdk.init();
  });

  group('Key Generation Tests', () {
    test('should generate correct keypair from known mnemonic phrase', () {
      // This is a valid BIP39 mnemonic phrase - DO NOT use for real wallets
      const testMnemonic =
          'situate more drip void arrest just action prepare engine undo honey delay sponsor come achieve symptom crumble solution glass garden fury valid garbage old';

      // Generate keypair from mnemonic
      final keypair = generateKeypair(mnemonicStr: testMnemonic);

      // Verify keypair was generated
      expect(keypair, isNotNull);
      expect(keypair.publicKey, isNotEmpty);
      expect(keypair.secretKey, isNotEmpty);

      // Convert to account ID
      final accountId = toAccountId(obj: keypair);

      // Verify account ID format (should be a valid SS58 address)
      expect(accountId, isNotEmpty);
      expect(
        accountId.startsWith('qz'),
        isTrue,
      ); // SS58 addresses typically start with '5'

      // Test signing and verification
      final message = [1, 2, 3, 4, 5];
      final signature = signMessage(keypair: keypair, message: message);

      // Verify signature
      expect(signature, isNotEmpty);

      // Verify the signature is valid
      final isValid = verifyMessage(
        keypair: keypair,
        message: message,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    test('should generate different keypairs for different mnemonics', () {
      // These are valid BIP39 mnemonics - DO NOT use for real wallets
      const mnemonic1 =
          'situate more drip void arrest just action prepare engine undo honey delay sponsor come achieve symptom crumble solution glass garden fury valid garbage old';
      const mnemonic2 =
          'famous laundry soldier gift source below kangaroo scorpion lesson vast welcome grow culture picture chronic sun surge eight cabbage miss hair boss pelican stem';

      final keypair1 = generateKeypair(mnemonicStr: mnemonic1);
      final keypair2 = generateKeypair(mnemonicStr: mnemonic2);

      // Verify different mnemonics generate different keypairs
      expect(keypair1.publicKey, isNot(equals(keypair2.publicKey)));
      expect(keypair1.secretKey, isNot(equals(keypair2.secretKey)));
    });

    test('test for known values', () {
      const mnemonic1 =
          'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';

      const knownAccountId =
          'qzpKnCCUvfXQdanRBkoPVDxcXbLja9JkYzv26hTQwP9C5mZWP'; // schroedinger chain spec
      const knownPublicKey = '0xa1063473a31ea7462f1f2324d6fdb30971dc2b300f81daf03564791913c8422f0a301693d590f4d0f503f4c2a620a08beacbde4acfd661385641c89f151f02397bbb8866294970e69907e093a6eb32fdf9a7919b764df445ce9238fbaad0fb23d8c122648669a81cff69bc43d4e5f369039f33888219beaa7338dbdcbb2f6663e10619112366c4a5a6897c181bbb31e4aa78b55f5d40cc2d2c7bf07e67879be6119ea5210a95bb53ddd0a513c472300a83190fbc64391a447ddcd34ce558ee066f4aa6a13253f9729bc6eef9307240db66200fdcc76bc4fd3a0706371db46c3b13410de623a030d282226239a1463034b5e35f187317d2a2ade405b4b17a91a4c4aeda46e0b5af1e507a43ec0fd24c9186aa92ebdaf3ecf5dda5846ac4ebe6076352909d7d9f0e02e5a61430cebad063939eb8e757a12246157b81810268a3606d1513f4ef8168634992707f71b3c286e95f39c9f86b5a8fbfaf5b281abb09dfa495a3988901c9eb02dc3d6276877f37c8900bc43347296191499a6079575c5f5870a0f9d5590c30445b8d10a5122f0c832f92d514e5f5876fcd77bab3e44827776b73d5a72d7a8f6346d1f5a603bc87a41d2bbf050c2138033bf798f52bb64908de33b22e8636fa78def163dcad08834342d4faf5f8790b59ee1de3750fa7ef0e13bd33ef03ddb85468fe817401e17ca01d04738c47a89b97b35a8c7852c37ac45edd64a0fa0090a662f1c7840dfb743d6c6634696b2fb28789f052312e46750bd00eb75803cdbb71735290079ab9f32ce40925c774b5bc316f184cb2e12cbb45e809b1b39ab1a4d7cfbbf7680bf7e2ee206a97b35a8c28fe169e5ddc258a0700bc772ad181c2201f09ca7975d4483b74688ab71fe8fa227cc1f2e017c3c7e27a1fdaf938e03a692f607e36a99f48ff4224a0d0626769395d0c23c0b34db311100ca22051672b5c78971f0dc15b806ec9fcd78ee2fd446e4e1ccd998b39f7b1672ebb2067eda389554d9d7c7b5552c771d8f25844366ce206bdedc855fc3e0d85eafdc0ec0cd4b5eb6a76ed0e45ed552a5bf9f21039bc265dbc25b0efe62b254a6925b0ecc6890cde35b33cf4e939d7585ef6e8373d1aafa0279a82ba4592e7e25aaebb4a90c76380478ed2f4816b71074bac1f53425d7e79d58ec0ffb104ef77bbbf35eb9752574a78a6ee31f0026a921a26ceea82120521a30f8015e5414499f688c56a882595579d035a6d48509fecf6e4373f52e9f1a3bf005e681d832399ed8b38f9dd83b29c4dc7970a082b86aa3f593169f434da7e5723c7c086baf2ef25375f48cebc162686b78747f4fcd3b0ae2cac37edc649df4bd142530449d03ec2945146e543b4370d5372183797e51ba741bbbff7c0451f513926a749e75acf285022fdb1e41233101114f5c0955cb6474e80f8dbd89849994d6ea3f4de87f54ad51d628d28feb04af86b53d8dbf9bccae9eff3f7364bf6f6776c3a96331bf9f389092aa6df650c550cd9d6d3a60160b753e10f3d0477490e3719a91b4448e15e60ce287a96577e414344a4f28d90cb0e05f39223d9b97174c72914abcfbd876de04e6e9b435d40cc56bc91af8c165e0fd8bb5f6f70084c53434fc9ce23d0c0bb46a6928265c8f0b0a1c417330c774d918f233b56ccf9bff80ceb7ae050ca5a5e534933f77f873a2735db4ccd0a728569fb32986414497ef26263fe52df7a2d7ebca24186c50a36106fceaa8d07ba2cd0a232d00f207f6ff5d1965dafafda01940f168ce99627cc4a5b6954f7cca72a2de8e9031566f4780132ff97853ca9e8f0698ab9e2929121eef3dfc5ebe7a5db4a71d46680874f09fce6e75de2035abe0818fa4d008a8bf3e985aaf15e977fb0d4c9abc2fd04472d170e00cc13bf0957d89d6e26ae84fe4e24e06297d0eb473ec7c8fe78d0dfd77fb2c80f27a058ab52ad54c3ad7bd981950157b60cc7d6c2568c5b88c8864b3d0de1e5456f72c8a65b5ea5c02d10f1c90f6e3331dfcade1033161623fe248632f3b55a02c5288d92391054e464e51545527e4eea44bc1685f88a0a37d5134b0b5c6882ba27c9840954c2d8a22dd87f660666715cee0b56c55cca0d23365e21b27becb46356ed70b3f0d361f0a797507e34e980f701a49ac206afb9fc14dcfb3891ae3eae98dbfe36e345c65b5e99982458960bd01a5573e300cb42ba71237391cfcc6f6c0dd9e83fd70ac3046700b7bbaba918889d267e954743834a106af9d99542101314d602177bc2b5fa93e8e08a03e1588c95c6d2542604459b1693215a75952343ef2d2c1db570192968a31b20a3b87e120a89c08a683757f71b0086b96da17248fc5423e1be78958b0b9a1a12b5c47e448cd021a07e103a053bb2061ebabadfe86bac6a650f6b0e5e122c867464ade254e7f76ad572972c2212e47a233bb30a10442715c2855d2f14b5c04103a56ab18de8fa58d9cc94c10dabb14d63d85164d64a4764c4960b82ee41b7be34806ef0159bb343b0e7961c2e872ed7c7c3b3a7beac4997549f5420a84f8f4ea8d480de2531fec9ef9169cfb891efad56702d417536b6f607e400a19420508d25e17fd1f123c2abef263b2d3534a7345f383aa3378aabc7541c4b12bfd251db8b2cbc5ba7e53f809e641ae3387e7ec7cc2a85a221b8885cf62a38d7f7c956590927db0d0fa2c207983ca4b70e759c9163869127d4e89463469fc381cc4dce196ca29775b344ce2bf43ded087a6de42f89b45e31faefac7970c27cc34e159d2d1729249b19265c5e16c98c4c65094a7e3d35438a0d980dff8963f3f68968957cd9d5dd73df73d7393bab8c2a9e325c819cf3a301dc678139f0649070723551b00fb6a842ae09b79285f86b5fac3a318b6b31b9e3090bd66cbc7c75c7932020c0003824927f9c09f0300011ad380483a11691c23c99497bebea253f0e65fd8e028bc8e50cab4a1ab37fe788262489508714c5deea8b5c1b70dd3b3e6a252899687e7aaad7c16984ad9aaf69335cc8e0b3e39612c1db36e72f1627a4d35e7c53bd6186f2666f059705d585020bc5ca30ddc0d5b7f19e04d76efaf18ea48b1882197807d8a381c17451b6444cd58d1233a226d6c6c9ea20a19dbe740e3094470f1d46f5c51a37a6a1263a171499961620a97a14f5fe99ae7e31f5babd453ca103cb550b9d2cae47f0f27d83b045c33b079640a3f2fe697e412940ee7c72c7d5a665415589297793f9dc4a87c9b9a5a4bdfd517792401b2a96434226faee9efb8dbfefa90fd7ad28dca4a80674534c36d8a65e9eafc7feb683211bafc3be739cc6e851650e78adcd41ec3c065e1a36b6f041218ce8000c65fccc4eee3633224209b4b081521ec7bcde49bc348161c562cbf1d7a229e5492c8a70e0abc674323a68634cdb2e70b0f43553ec49209747ea260417e33212e79360cbb14d7d5ea8e990d6dcfbd0eb42f09857c97cac3acec5efe6c5670a7fe377e2cc2f19dd5cef4bf5fd49c8af1a0d4c5d428a525568a056100b0a9727086f304ccb1d67bed6c16d58411f46d6bd8f7bccf251b710cc303994d1890739df7b9233074c509506055f3b09343742e2688d64c80d728155bb424cb6c6076e21ae1c56b645f199a87954d7117d3372bd76ffce291a7a65ebb3813a87dd77eff1063c0adff0';
      final keypair = generateKeypair(mnemonicStr: mnemonic1);
      final accountId = toAccountId(obj: keypair);

      expect(accountId, knownAccountId);
      expect(keypair.publicKey, hex.decode(knownPublicKey));
    });
  });
}
