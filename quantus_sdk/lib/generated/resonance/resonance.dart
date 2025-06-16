// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i23;

import 'package:polkadart/polkadart.dart' as _i1;

import 'pallets/balances.dart' as _i4;
import 'pallets/conviction_voting.dart' as _i15;
import 'pallets/faucet.dart' as _i22;
import 'pallets/merkle_airdrop.dart' as _i18;
import 'pallets/mining_rewards.dart' as _i9;
import 'pallets/preimage.dart' as _i11;
import 'pallets/q_po_w.dart' as _i7;
import 'pallets/recovery.dart' as _i20;
import 'pallets/referenda.dart' as _i13;
import 'pallets/reversible_transfers.dart' as _i14;
import 'pallets/scheduler.dart' as _i12;
import 'pallets/sudo.dart' as _i6;
import 'pallets/system.dart' as _i2;
import 'pallets/tech_collective.dart' as _i16;
import 'pallets/tech_referenda.dart' as _i17;
import 'pallets/timestamp.dart' as _i3;
import 'pallets/transaction_payment.dart' as _i5;
import 'pallets/treasury_pallet.dart' as _i19;
import 'pallets/utility.dart' as _i21;
import 'pallets/vesting.dart' as _i10;
import 'pallets/wormhole.dart' as _i8;

class Queries {
  Queries(_i1.StateApi api)
      : system = _i2.Queries(api),
        timestamp = _i3.Queries(api),
        balances = _i4.Queries(api),
        transactionPayment = _i5.Queries(api),
        sudo = _i6.Queries(api),
        qPoW = _i7.Queries(api),
        wormhole = _i8.Queries(api),
        miningRewards = _i9.Queries(api),
        vesting = _i10.Queries(api),
        preimage = _i11.Queries(api),
        scheduler = _i12.Queries(api),
        referenda = _i13.Queries(api),
        reversibleTransfers = _i14.Queries(api),
        convictionVoting = _i15.Queries(api),
        techCollective = _i16.Queries(api),
        techReferenda = _i17.Queries(api),
        merkleAirdrop = _i18.Queries(api),
        treasuryPallet = _i19.Queries(api),
        recovery = _i20.Queries(api);

  final _i2.Queries system;

  final _i3.Queries timestamp;

  final _i4.Queries balances;

  final _i5.Queries transactionPayment;

  final _i6.Queries sudo;

  final _i7.Queries qPoW;

  final _i8.Queries wormhole;

  final _i9.Queries miningRewards;

  final _i10.Queries vesting;

  final _i11.Queries preimage;

  final _i12.Queries scheduler;

  final _i13.Queries referenda;

  final _i14.Queries reversibleTransfers;

  final _i15.Queries convictionVoting;

  final _i16.Queries techCollective;

  final _i17.Queries techReferenda;

  final _i18.Queries merkleAirdrop;

  final _i19.Queries treasuryPallet;

  final _i20.Queries recovery;
}

class Extrinsics {
  Extrinsics();

  final _i2.Txs system = _i2.Txs();

  final _i3.Txs timestamp = _i3.Txs();

  final _i4.Txs balances = _i4.Txs();

  final _i6.Txs sudo = _i6.Txs();

  final _i8.Txs wormhole = _i8.Txs();

  final _i10.Txs vesting = _i10.Txs();

  final _i11.Txs preimage = _i11.Txs();

  final _i12.Txs scheduler = _i12.Txs();

  final _i21.Txs utility = _i21.Txs();

  final _i13.Txs referenda = _i13.Txs();

  final _i14.Txs reversibleTransfers = _i14.Txs();

  final _i15.Txs convictionVoting = _i15.Txs();

  final _i16.Txs techCollective = _i16.Txs();

  final _i17.Txs techReferenda = _i17.Txs();

  final _i18.Txs merkleAirdrop = _i18.Txs();

  final _i19.Txs treasuryPallet = _i19.Txs();

  final _i22.Txs faucet = _i22.Txs();

  final _i20.Txs recovery = _i20.Txs();
}

class Constants {
  Constants();

  final _i2.Constants system = _i2.Constants();

  final _i3.Constants timestamp = _i3.Constants();

  final _i4.Constants balances = _i4.Constants();

  final _i5.Constants transactionPayment = _i5.Constants();

  final _i7.Constants qPoW = _i7.Constants();

  final _i9.Constants miningRewards = _i9.Constants();

  final _i10.Constants vesting = _i10.Constants();

  final _i12.Constants scheduler = _i12.Constants();

  final _i21.Constants utility = _i21.Constants();

  final _i13.Constants referenda = _i13.Constants();

  final _i14.Constants reversibleTransfers = _i14.Constants();

  final _i15.Constants convictionVoting = _i15.Constants();

  final _i17.Constants techReferenda = _i17.Constants();

  final _i18.Constants merkleAirdrop = _i18.Constants();

  final _i19.Constants treasuryPallet = _i19.Constants();

  final _i22.Constants faucet = _i22.Constants();

  final _i20.Constants recovery = _i20.Constants();
}

class Rpc {
  const Rpc({
    required this.state,
    required this.system,
  });

  final _i1.StateApi state;

  final _i1.SystemApi system;
}

class Registry {
  Registry();

  final int extrinsicVersion = 4;

  List getSignedExtensionTypes() {
    return [
      'CheckMortality',
      'CheckNonce',
      'ChargeTransactionPayment',
      'CheckMetadataHash'
    ];
  }

  List getSignedExtensionExtra() {
    return [
      'CheckSpecVersion',
      'CheckTxVersion',
      'CheckGenesis',
      'CheckMortality',
      'CheckMetadataHash'
    ];
  }
}

class Resonance {
  Resonance._(
    this._provider,
    this.rpc,
  )   : query = Queries(rpc.state),
        constant = Constants(),
        tx = Extrinsics(),
        registry = Registry();

  factory Resonance(_i1.Provider provider) {
    final rpc = Rpc(
      state: _i1.StateApi(provider),
      system: _i1.SystemApi(provider),
    );
    return Resonance._(
      provider,
      rpc,
    );
  }

  factory Resonance.url(Uri url) {
    final provider = _i1.Provider.fromUri(url);
    return Resonance(provider);
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
