// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i10;

import 'package:polkadart/polkadart.dart' as _i1;

import 'pallets/balances.dart' as _i4;
import 'pallets/q_po_w.dart' as _i8;
import 'pallets/sudo.dart' as _i6;
import 'pallets/system.dart' as _i2;
import 'pallets/template.dart' as _i7;
import 'pallets/timestamp.dart' as _i3;
import 'pallets/transaction_payment.dart' as _i5;
import 'pallets/wormhole.dart' as _i9;

class Queries {
  Queries(_i1.StateApi api)
      : system = _i2.Queries(api),
        timestamp = _i3.Queries(api),
        balances = _i4.Queries(api),
        transactionPayment = _i5.Queries(api),
        sudo = _i6.Queries(api),
        template = _i7.Queries(api),
        qPoW = _i8.Queries(api),
        wormhole = _i9.Queries(api);

  final _i2.Queries system;

  final _i3.Queries timestamp;

  final _i4.Queries balances;

  final _i5.Queries transactionPayment;

  final _i6.Queries sudo;

  final _i7.Queries template;

  final _i8.Queries qPoW;

  final _i9.Queries wormhole;
}

class Extrinsics {
  Extrinsics();

  final _i2.Txs system = const _i2.Txs();

  final _i3.Txs timestamp = const _i3.Txs();

  final _i4.Txs balances = const _i4.Txs();

  final _i6.Txs sudo = const _i6.Txs();

  final _i7.Txs template = const _i7.Txs();

  final _i9.Txs wormhole = const _i9.Txs();
}

class Constants {
  Constants();

  final _i2.Constants system = _i2.Constants();

  final _i3.Constants timestamp = _i3.Constants();

  final _i4.Constants balances = _i4.Constants();

  final _i5.Constants transactionPayment = _i5.Constants();

  final _i8.Constants qPoW = _i8.Constants();
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

  _i10.Future connect() async {
    return await _provider.connect();
  }

  _i10.Future disconnect() async {
    return await _provider.disconnect();
  }
}
