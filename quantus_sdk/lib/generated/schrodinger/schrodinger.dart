// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i23;

import 'package:polkadart/polkadart.dart' as _i1;

import 'pallets/assets.dart' as _i20;
import 'pallets/assets_holder.dart' as _i21;
import 'pallets/balances.dart' as _i4;
import 'pallets/conviction_voting.dart' as _i14;
import 'pallets/merkle_airdrop.dart' as _i17;
import 'pallets/mining_rewards.dart' as _i8;
import 'pallets/preimage.dart' as _i10;
import 'pallets/q_po_w.dart' as _i7;
import 'pallets/recovery.dart' as _i19;
import 'pallets/referenda.dart' as _i12;
import 'pallets/reversible_transfers.dart' as _i13;
import 'pallets/scheduler.dart' as _i11;
import 'pallets/sudo.dart' as _i6;
import 'pallets/system.dart' as _i2;
import 'pallets/tech_collective.dart' as _i15;
import 'pallets/tech_referenda.dart' as _i16;
import 'pallets/timestamp.dart' as _i3;
import 'pallets/transaction_payment.dart' as _i5;
import 'pallets/treasury_pallet.dart' as _i18;
import 'pallets/utility.dart' as _i22;
import 'pallets/vesting.dart' as _i9;

class Queries {
  Queries(_i1.StateApi api)
    : system = _i2.Queries(api),
      timestamp = _i3.Queries(api),
      balances = _i4.Queries(api),
      transactionPayment = _i5.Queries(api),
      sudo = _i6.Queries(api),
      qPoW = _i7.Queries(api),
      miningRewards = _i8.Queries(api),
      vesting = _i9.Queries(api),
      preimage = _i10.Queries(api),
      scheduler = _i11.Queries(api),
      referenda = _i12.Queries(api),
      reversibleTransfers = _i13.Queries(api),
      convictionVoting = _i14.Queries(api),
      techCollective = _i15.Queries(api),
      techReferenda = _i16.Queries(api),
      merkleAirdrop = _i17.Queries(api),
      treasuryPallet = _i18.Queries(api),
      recovery = _i19.Queries(api),
      assets = _i20.Queries(api),
      assetsHolder = _i21.Queries(api);

  final _i2.Queries system;

  final _i3.Queries timestamp;

  final _i4.Queries balances;

  final _i5.Queries transactionPayment;

  final _i6.Queries sudo;

  final _i7.Queries qPoW;

  final _i8.Queries miningRewards;

  final _i9.Queries vesting;

  final _i10.Queries preimage;

  final _i11.Queries scheduler;

  final _i12.Queries referenda;

  final _i13.Queries reversibleTransfers;

  final _i14.Queries convictionVoting;

  final _i15.Queries techCollective;

  final _i16.Queries techReferenda;

  final _i17.Queries merkleAirdrop;

  final _i18.Queries treasuryPallet;

  final _i19.Queries recovery;

  final _i20.Queries assets;

  final _i21.Queries assetsHolder;
}

class Extrinsics {
  Extrinsics();

  final _i2.Txs system = _i2.Txs();

  final _i3.Txs timestamp = _i3.Txs();

  final _i4.Txs balances = _i4.Txs();

  final _i6.Txs sudo = _i6.Txs();

  final _i9.Txs vesting = _i9.Txs();

  final _i10.Txs preimage = _i10.Txs();

  final _i11.Txs scheduler = _i11.Txs();

  final _i22.Txs utility = _i22.Txs();

  final _i12.Txs referenda = _i12.Txs();

  final _i13.Txs reversibleTransfers = _i13.Txs();

  final _i14.Txs convictionVoting = _i14.Txs();

  final _i15.Txs techCollective = _i15.Txs();

  final _i16.Txs techReferenda = _i16.Txs();

  final _i17.Txs merkleAirdrop = _i17.Txs();

  final _i18.Txs treasuryPallet = _i18.Txs();

  final _i19.Txs recovery = _i19.Txs();

  final _i20.Txs assets = _i20.Txs();
}

class Constants {
  Constants();

  final _i2.Constants system = _i2.Constants();

  final _i3.Constants timestamp = _i3.Constants();

  final _i4.Constants balances = _i4.Constants();

  final _i5.Constants transactionPayment = _i5.Constants();

  final _i7.Constants qPoW = _i7.Constants();

  final _i8.Constants miningRewards = _i8.Constants();

  final _i9.Constants vesting = _i9.Constants();

  final _i11.Constants scheduler = _i11.Constants();

  final _i22.Constants utility = _i22.Constants();

  final _i12.Constants referenda = _i12.Constants();

  final _i13.Constants reversibleTransfers = _i13.Constants();

  final _i14.Constants convictionVoting = _i14.Constants();

  final _i16.Constants techReferenda = _i16.Constants();

  final _i17.Constants merkleAirdrop = _i17.Constants();

  final _i18.Constants treasuryPallet = _i18.Constants();

  final _i19.Constants recovery = _i19.Constants();

  final _i20.Constants assets = _i20.Constants();
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

class Schrodinger {
  Schrodinger._(this._provider, this.rpc)
    : query = Queries(rpc.state),
      constant = Constants(),
      tx = Extrinsics(),
      registry = Registry();

  factory Schrodinger(_i1.Provider provider) {
    final rpc = Rpc(state: _i1.StateApi(provider), system: _i1.SystemApi(provider));
    return Schrodinger._(provider, rpc);
  }

  factory Schrodinger.url(Uri url) {
    final provider = _i1.Provider.fromUri(url);
    return Schrodinger(provider);
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
