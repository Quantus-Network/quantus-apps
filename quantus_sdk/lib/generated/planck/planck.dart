// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i23;

import 'package:polkadart/polkadart.dart' as _i1;

import 'pallets/assets.dart' as _i17;
import 'pallets/assets_holder.dart' as _i18;
import 'pallets/balances.dart' as _i4;
import 'pallets/conviction_voting.dart' as _i12;
import 'pallets/mining_rewards.dart' as _i7;
import 'pallets/multisig.dart' as _i19;
import 'pallets/preimage.dart' as _i8;
import 'pallets/q_po_w.dart' as _i6;
import 'pallets/recovery.dart' as _i16;
import 'pallets/referenda.dart' as _i10;
import 'pallets/reversible_transfers.dart' as _i11;
import 'pallets/scheduler.dart' as _i9;
import 'pallets/system.dart' as _i2;
import 'pallets/tech_collective.dart' as _i13;
import 'pallets/tech_referenda.dart' as _i14;
import 'pallets/timestamp.dart' as _i3;
import 'pallets/transaction_payment.dart' as _i5;
import 'pallets/treasury_pallet.dart' as _i15;
import 'pallets/utility.dart' as _i22;
import 'pallets/wormhole.dart' as _i20;
import 'pallets/zk_tree.dart' as _i21;

class Queries {
  Queries(_i1.StateApi api)
    : system = _i2.Queries(api),
      timestamp = _i3.Queries(api),
      balances = _i4.Queries(api),
      transactionPayment = _i5.Queries(api),
      qPoW = _i6.Queries(api),
      miningRewards = _i7.Queries(api),
      preimage = _i8.Queries(api),
      scheduler = _i9.Queries(api),
      referenda = _i10.Queries(api),
      reversibleTransfers = _i11.Queries(api),
      convictionVoting = _i12.Queries(api),
      techCollective = _i13.Queries(api),
      techReferenda = _i14.Queries(api),
      treasuryPallet = _i15.Queries(api),
      recovery = _i16.Queries(api),
      assets = _i17.Queries(api),
      assetsHolder = _i18.Queries(api),
      multisig = _i19.Queries(api),
      wormhole = _i20.Queries(api),
      zkTree = _i21.Queries(api);

  final _i2.Queries system;

  final _i3.Queries timestamp;

  final _i4.Queries balances;

  final _i5.Queries transactionPayment;

  final _i6.Queries qPoW;

  final _i7.Queries miningRewards;

  final _i8.Queries preimage;

  final _i9.Queries scheduler;

  final _i10.Queries referenda;

  final _i11.Queries reversibleTransfers;

  final _i12.Queries convictionVoting;

  final _i13.Queries techCollective;

  final _i14.Queries techReferenda;

  final _i15.Queries treasuryPallet;

  final _i16.Queries recovery;

  final _i17.Queries assets;

  final _i18.Queries assetsHolder;

  final _i19.Queries multisig;

  final _i20.Queries wormhole;

  final _i21.Queries zkTree;
}

class Extrinsics {
  Extrinsics();

  final _i2.Txs system = _i2.Txs();

  final _i3.Txs timestamp = _i3.Txs();

  final _i4.Txs balances = _i4.Txs();

  final _i8.Txs preimage = _i8.Txs();

  final _i9.Txs scheduler = _i9.Txs();

  final _i22.Txs utility = _i22.Txs();

  final _i10.Txs referenda = _i10.Txs();

  final _i11.Txs reversibleTransfers = _i11.Txs();

  final _i12.Txs convictionVoting = _i12.Txs();

  final _i13.Txs techCollective = _i13.Txs();

  final _i14.Txs techReferenda = _i14.Txs();

  final _i15.Txs treasuryPallet = _i15.Txs();

  final _i16.Txs recovery = _i16.Txs();

  final _i17.Txs assets = _i17.Txs();

  final _i19.Txs multisig = _i19.Txs();

  final _i20.Txs wormhole = _i20.Txs();
}

class Constants {
  Constants();

  final _i2.Constants system = _i2.Constants();

  final _i3.Constants timestamp = _i3.Constants();

  final _i4.Constants balances = _i4.Constants();

  final _i5.Constants transactionPayment = _i5.Constants();

  final _i6.Constants qPoW = _i6.Constants();

  final _i7.Constants miningRewards = _i7.Constants();

  final _i9.Constants scheduler = _i9.Constants();

  final _i22.Constants utility = _i22.Constants();

  final _i10.Constants referenda = _i10.Constants();

  final _i11.Constants reversibleTransfers = _i11.Constants();

  final _i12.Constants convictionVoting = _i12.Constants();

  final _i14.Constants techReferenda = _i14.Constants();

  final _i16.Constants recovery = _i16.Constants();

  final _i17.Constants assets = _i17.Constants();

  final _i19.Constants multisig = _i19.Constants();

  final _i20.Constants wormhole = _i20.Constants();
}

class Rpc {
  const Rpc({required this.state, required this.system});

  final _i1.StateApi state;

  final _i1.SystemApi system;
}

class Registry {
  Registry();

  final int extrinsicVersion = 4;

  List getSignedExtensionTypes() {
    return ['CheckMortality', 'CheckNonce', 'ChargeTransactionPayment', 'CheckMetadataHash'];
  }

  List getSignedExtensionExtra() {
    return ['CheckSpecVersion', 'CheckTxVersion', 'CheckGenesis', 'CheckMortality', 'CheckMetadataHash'];
  }
}

class Planck {
  Planck._(this._provider, this.rpc)
    : query = Queries(rpc.state),
      constant = Constants(),
      tx = Extrinsics(),
      registry = Registry();

  factory Planck(_i1.Provider provider) {
    final rpc = Rpc(state: _i1.StateApi(provider), system: _i1.SystemApi(provider));
    return Planck._(provider, rpc);
  }

  factory Planck.url(Uri url) {
    final provider = _i1.Provider.fromUri(url);
    return Planck(provider);
  }

  final _i1.Provider _provider;

  final Queries query;

  final Constants constant;

  final Rpc rpc;

  final Extrinsics tx;

  final Registry registry;

  _i23.Future connect() async {
    return await _provider.connect();
  }

  _i23.Future disconnect() async {
    return await _provider.disconnect();
  }
}
