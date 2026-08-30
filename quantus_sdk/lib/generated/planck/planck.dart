// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i19;

import 'package:polkadart/polkadart.dart' as _i1;

import 'pallets/balances.dart' as _i4;
import 'pallets/mining_rewards.dart' as _i7;
import 'pallets/multisig.dart' as _i14;
import 'pallets/preimage.dart' as _i8;
import 'pallets/q_po_w.dart' as _i6;
import 'pallets/reversible_transfers.dart' as _i10;
import 'pallets/scheduler.dart' as _i9;
import 'pallets/system.dart' as _i2;
import 'pallets/tech_collective.dart' as _i11;
import 'pallets/tech_referenda.dart' as _i12;
import 'pallets/timestamp.dart' as _i3;
import 'pallets/transaction_payment.dart' as _i5;
import 'pallets/treasury_pallet.dart' as _i13;
import 'pallets/utility.dart' as _i18;
import 'pallets/vesting.dart' as _i17;
import 'pallets/wormhole.dart' as _i15;
import 'pallets/zk_tree.dart' as _i16;

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
      reversibleTransfers = _i10.Queries(api),
      techCollective = _i11.Queries(api),
      techReferenda = _i12.Queries(api),
      treasuryPallet = _i13.Queries(api),
      multisig = _i14.Queries(api),
      wormhole = _i15.Queries(api),
      zkTree = _i16.Queries(api),
      vesting = _i17.Queries(api);

  final _i2.Queries system;

  final _i3.Queries timestamp;

  final _i4.Queries balances;

  final _i5.Queries transactionPayment;

  final _i6.Queries qPoW;

  final _i7.Queries miningRewards;

  final _i8.Queries preimage;

  final _i9.Queries scheduler;

  final _i10.Queries reversibleTransfers;

  final _i11.Queries techCollective;

  final _i12.Queries techReferenda;

  final _i13.Queries treasuryPallet;

  final _i14.Queries multisig;

  final _i15.Queries wormhole;

  final _i16.Queries zkTree;

  final _i17.Queries vesting;
}

class Extrinsics {
  Extrinsics();

  final _i2.Txs system = _i2.Txs();

  final _i3.Txs timestamp = _i3.Txs();

  final _i4.Txs balances = _i4.Txs();

  final _i8.Txs preimage = _i8.Txs();

  final _i18.Txs utility = _i18.Txs();

  final _i10.Txs reversibleTransfers = _i10.Txs();

  final _i11.Txs techCollective = _i11.Txs();

  final _i12.Txs techReferenda = _i12.Txs();

  final _i13.Txs treasuryPallet = _i13.Txs();

  final _i14.Txs multisig = _i14.Txs();

  final _i15.Txs wormhole = _i15.Txs();

  final _i17.Txs vesting = _i17.Txs();
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

  final _i18.Constants utility = _i18.Constants();

  final _i10.Constants reversibleTransfers = _i10.Constants();

  final _i12.Constants techReferenda = _i12.Constants();

  final _i14.Constants multisig = _i14.Constants();

  final _i15.Constants wormhole = _i15.Constants();

  final _i17.Constants vesting = _i17.Constants();
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

  _i19.Future connect() async {
    return await _provider.connect();
  }

  _i19.Future disconnect() async {
    return await _provider.disconnect();
  }
}
