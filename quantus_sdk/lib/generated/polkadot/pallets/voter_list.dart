// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;
import 'dart:typed_data' as _i7;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i4;

import '../types/pallet_bags_list/list/bag.dart' as _i5;
import '../types/pallet_bags_list/list/node.dart' as _i3;
import '../types/pallet_bags_list/pallet/call.dart' as _i10;
import '../types/polkadot_runtime/runtime_call.dart' as _i8;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i9;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.Node> _listNodes =
      const _i1.StorageMap<_i2.AccountId32, _i3.Node>(
    prefix: 'VoterList',
    storage: 'ListNodes',
    valueCodec: _i3.Node.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageValue<int> _counterForListNodes =
      const _i1.StorageValue<int>(
    prefix: 'VoterList',
    storage: 'CounterForListNodes',
    valueCodec: _i4.U32Codec.codec,
  );

  final _i1.StorageMap<BigInt, _i5.Bag> _listBags =
      const _i1.StorageMap<BigInt, _i5.Bag>(
    prefix: 'VoterList',
    storage: 'ListBags',
    valueCodec: _i5.Bag.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i4.U64Codec.codec),
  );

  /// A single node, within some bag.
  ///
  /// Nodes store links forward and back within their respective bags.
  _i6.Future<_i3.Node?> listNodes(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _listNodes.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _listNodes.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Counter for the related counted storage map
  _i6.Future<int> counterForListNodes({_i1.BlockHash? at}) async {
    final hashedKey = _counterForListNodes.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _counterForListNodes.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// A bag stored in storage.
  ///
  /// Stores a `Bag` struct, which stores head and tail pointers to itself.
  _i6.Future<_i5.Bag?> listBags(
    BigInt key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _listBags.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _listBags.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// A single node, within some bag.
  ///
  /// Nodes store links forward and back within their respective bags.
  _i6.Future<List<_i3.Node?>> multiListNodes(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _listNodes.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _listNodes.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// A bag stored in storage.
  ///
  /// Stores a `Bag` struct, which stores head and tail pointers to itself.
  _i6.Future<List<_i5.Bag?>> multiListBags(
    List<BigInt> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _listBags.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _listBags.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `listNodes`.
  _i7.Uint8List listNodesKey(_i2.AccountId32 key1) {
    final hashedKey = _listNodes.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `counterForListNodes`.
  _i7.Uint8List counterForListNodesKey() {
    final hashedKey = _counterForListNodes.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `listBags`.
  _i7.Uint8List listBagsKey(BigInt key1) {
    final hashedKey = _listBags.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `listNodes`.
  _i7.Uint8List listNodesMapPrefix() {
    final hashedKey = _listNodes.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `listBags`.
  _i7.Uint8List listBagsMapPrefix() {
    final hashedKey = _listBags.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Declare that some `dislocated` account has, through rewards or penalties, sufficiently
  /// changed its score that it should properly fall into a different bag than its current
  /// one.
  ///
  /// Anyone can call this function about any potentially dislocated account.
  ///
  /// Will always update the stored score of `dislocated` to the correct score, based on
  /// `ScoreProvider`.
  ///
  /// If `dislocated` does not exists, it returns an error.
  _i8.VoterList rebag({required _i9.MultiAddress dislocated}) {
    return _i8.VoterList(_i10.Rebag(dislocated: dislocated));
  }

  /// Move the caller's Id directly in front of `lighter`.
  ///
  /// The dispatch origin for this call must be _Signed_ and can only be called by the Id of
  /// the account going in front of `lighter`. Fee is payed by the origin under all
  /// circumstances.
  ///
  /// Only works if:
  ///
  /// - both nodes are within the same bag,
  /// - and `origin` has a greater `Score` than `lighter`.
  _i8.VoterList putInFrontOf({required _i9.MultiAddress lighter}) {
    return _i8.VoterList(_i10.PutInFrontOf(lighter: lighter));
  }

  /// Same as [`Pallet::put_in_front_of`], but it can be called by anyone.
  ///
  /// Fee is paid by the origin under all circumstances.
  _i8.VoterList putInFrontOfOther({
    required _i9.MultiAddress heavier,
    required _i9.MultiAddress lighter,
  }) {
    return _i8.VoterList(_i10.PutInFrontOfOther(
      heavier: heavier,
      lighter: lighter,
    ));
  }
}

class Constants {
  Constants();

  /// The list of thresholds separating the various bags.
  ///
  /// Ids are separated into unsorted bags according to their score. This specifies the
  /// thresholds separating the bags. An id's bag is the largest bag for which the id's score
  /// is less than or equal to its upper threshold.
  ///
  /// When ids are iterated, higher bags are iterated completely before lower bags. This means
  /// that iteration is _semi-sorted_: ids of higher score tend to come before ids of lower
  /// score, but peer ids within a particular bag are sorted in insertion order.
  ///
  /// # Expressing the constant
  ///
  /// This constant must be sorted in strictly increasing order. Duplicate items are not
  /// permitted.
  ///
  /// There is an implied upper limit of `Score::MAX`; that value does not need to be
  /// specified within the bag. For any two threshold lists, if one ends with
  /// `Score::MAX`, the other one does not, and they are otherwise equal, the two
  /// lists will behave identically.
  ///
  /// # Calculation
  ///
  /// It is recommended to generate the set of thresholds in a geometric series, such that
  /// there exists some constant ratio such that `threshold[k + 1] == (threshold[k] *
  /// constant_ratio).max(threshold[k] + 1)` for all `k`.
  ///
  /// The helpers in the `/utils/frame/generate-bags` module can simplify this calculation.
  ///
  /// # Examples
  ///
  /// - If `BagThresholds::get().is_empty()`, then all ids are put into the same bag, and
  ///   iteration is strictly in insertion order.
  /// - If `BagThresholds::get().len() == 64`, and the thresholds are determined according to
  ///   the procedure given above, then the constant ratio is equal to 2.
  /// - If `BagThresholds::get().len() == 200`, and the thresholds are determined according to
  ///   the procedure given above, then the constant ratio is approximately equal to 1.248.
  /// - If the threshold list begins `[1, 2, 3, ...]`, then an id with score 0 or 1 will fall
  ///   into bag 0, an id with score 2 will fall into bag 1, etc.
  ///
  /// # Migration
  ///
  /// In the event that this list ever changes, a copy of the old bags list must be retained.
  /// With that `List::migrate` can be called, which will perform the appropriate migration.
  final List<BigInt> bagThresholds = <BigInt>[
    BigInt.from(10000000000),
    BigInt.from(11131723507),
    BigInt.from(12391526824),
    BigInt.from(13793905044),
    BigInt.from(15354993703),
    BigInt.from(17092754435),
    BigInt.from(19027181634),
    BigInt.from(21180532507),
    BigInt.from(23577583160),
    BigInt.from(26245913670),
    BigInt.from(29216225417),
    BigInt.from(32522694326),
    BigInt.from(36203364094),
    BigInt.from(40300583912),
    BigInt.from(44861495728),
    BigInt.from(49938576656),
    BigInt.from(55590242767),
    BigInt.from(61881521217),
    BigInt.from(68884798439),
    BigInt.from(76680653006),
    BigInt.from(85358782760),
    BigInt.from(95019036859),
    BigInt.from(105772564622),
    BigInt.from(117743094401),
    BigInt.from(131068357174),
    BigInt.from(145901671259),
    BigInt.from(162413706368),
    BigInt.from(180794447305),
    BigInt.from(201255379901),
    BigInt.from(224031924337),
    BigInt.from(249386143848),
    BigInt.from(277609759981),
    BigInt.from(309027509097),
    BigInt.from(344000878735),
    BigInt.from(382932266827),
    BigInt.from(426269611626),
    BigInt.from(474511545609),
    BigInt.from(528213132664),
    BigInt.from(587992254562),
    BigInt.from(654536720209),
    BigInt.from(728612179460),
    BigInt.from(811070932564),
    BigInt.from(902861736593),
    BigInt.from(1005040721687),
    BigInt.from(1118783542717),
    BigInt.from(1245398906179),
    BigInt.from(1386343627960),
    BigInt.from(1543239395225),
    BigInt.from(1717891425287),
    BigInt.from(1912309236147),
    BigInt.from(2128729767682),
    BigInt.from(2369643119512),
    BigInt.from(2637821201686),
    BigInt.from(2936349627828),
    BigInt.from(3268663217709),
    BigInt.from(3638585517729),
    BigInt.from(4050372794022),
    BigInt.from(4508763004364),
    BigInt.from(5019030312352),
    BigInt.from(5587045771074),
    BigInt.from(6219344874498),
    BigInt.from(6923202753807),
    BigInt.from(7706717883882),
    BigInt.from(8578905263043),
    BigInt.from(9549800138161),
    BigInt.from(10630573468586),
    BigInt.from(11833660457397),
    BigInt.from(13172903628838),
    BigInt.from(14663712098160),
    BigInt.from(16323238866411),
    BigInt.from(18170578180087),
    BigInt.from(20226985226447),
    BigInt.from(22516120692255),
    BigInt.from(25064322999817),
    BigInt.from(27900911352605),
    BigInt.from(31058523077268),
    BigInt.from(34573489143434),
    BigInt.from(38486252181966),
    BigInt.from(42841831811331),
    BigInt.from(47690342626046),
    BigInt.from(53087570807094),
    BigInt.from(59095615988698),
    BigInt.from(65783605766662),
    BigInt.from(73228491069308),
    BigInt.from(81515931542404),
    BigInt.from(90741281135191),
    BigInt.from(101010685227495),
    BigInt.from(112442301921293),
    BigInt.from(125167661548718),
    BigInt.from(139333180038781),
    BigInt.from(155101843555358),
    BigInt.from(172655083789626),
    BigInt.from(192194865483744),
    BigInt.from(213946010204502),
    BigInt.from(238158783103893),
    BigInt.from(265111772429462),
    BigInt.from(295115094915607),
    BigInt.from(328513963936552),
    BigInt.from(365692661475578),
    BigInt.from(407078959611349),
    BigInt.from(453149042394237),
    BigInt.from(504432984742966),
    BigInt.from(561520851400862),
    BigInt.from(625069486125324),
    BigInt.from(695810069225823),
    BigInt.from(774556530406243),
    BigInt.from(862214913708369),
    BigInt.from(959793802308039),
    BigInt.from(1068415923109985),
    BigInt.from(1189331064661951),
    BigInt.from(1323930457019515),
    BigInt.from(1473762779014021),
    BigInt.from(1640551977100649),
    BigInt.from(1826217100807404),
    BigInt.from(2032894383008501),
    BigInt.from(2262961819074188),
    BigInt.from(2519066527700738),
    BigInt.from(2804155208229882),
    BigInt.from(3121508044894685),
    BigInt.from(3474776448088622),
    BigInt.from(3868025066902796),
    BigInt.from(4305778556320752),
    BigInt.from(4793073637166665),
    BigInt.from(5335517047800242),
    BigInt.from(5939350054341159),
    BigInt.from(6611520261667250),
    BigInt.from(7359761551432161),
    BigInt.from(8192683066856378),
    BigInt.from(9119868268136230),
    BigInt.from(10151985198186376),
    BigInt.from(11300909227415580),
    BigInt.from(12579859689817292),
    BigInt.from(14003551982487792),
    BigInt.from(15588366878604342),
    BigInt.from(17352539001951086),
    BigInt.from(19316366631550092),
    BigInt.from(21502445250375680),
    BigInt.from(23935927525325748),
    BigInt.from(26644812709737600),
    BigInt.from(29660268798266784),
    BigInt.from(33016991140790860),
    BigInt.from(36753601641491664),
    BigInt.from(40913093136236104),
    BigInt.from(45543324061189736),
    BigInt.from(50697569104240168),
    BigInt.from(56435132174936472),
    BigInt.from(62822028745677552),
    BigInt.from(69931745415056768),
    BigInt.from(77846085432775824),
    BigInt.from(86656109914600688),
    BigInt.from(96463185576826656),
    BigInt.from(107380151045315664),
    BigInt.from(119532615158469088),
    BigInt.from(133060402202199856),
    BigInt.from(148119160705543712),
    BigInt.from(164882154307451552),
    BigInt.from(183542255300186560),
    BigInt.from(204314163786713728),
    BigInt.from(227436877985347776),
    BigInt.from(253176444104585088),
    BigInt.from(281829017427734464),
    BigInt.from(313724269827691328),
    BigInt.from(349229182918168832),
    BigInt.from(388752270484770624),
    BigInt.from(432748278778513664),
    BigInt.from(481723418752617984),
    BigInt.from(536241190443833600),
    BigInt.from(596928866512693376),
    BigInt.from(664484709541257600),
    BigInt.from(739686006129409280),
    BigInt.from(823398010228713984),
    BigInt.from(916583898614395264),
    BigInt.from(1020315853041475584),
    BigInt.from(1135787396594579584),
    BigInt.from(1264327126171442688),
    BigInt.from(1407413999103859968),
    BigInt.from(1566694349801462272),
    BigInt.from(1744000832209069824),
    BigInt.from(1941373506026471680),
    BigInt.from(2161083309305266176),
    BigInt.from(2405658187494662656),
    BigInt.from(2677912179572818944),
    BigInt.from(2980977795924034048),
    BigInt.from(3318342060496414208),
    BigInt.from(3693886631935247360),
    BigInt.from(4111932465319354368),
    BigInt.from(4577289528371127808),
    BigInt.from(5095312144166932480),
    BigInt.from(5671960597112134656),
    BigInt.from(6313869711009142784),
    BigInt.from(7028425188266614784),
    BigInt.from(7823848588596424704),
    BigInt.from(8709291924949524480),
    BigInt.from(9223372036854775807),
    BigInt.from(9223372036854775807),
    BigInt.from(9223372036854775807),
    BigInt.from(9223372036854775807),
    BigInt.from(9223372036854775807),
    BigInt.from(9223372036854775807),
    BigInt.from(9223372036854775807),
  ];
}
