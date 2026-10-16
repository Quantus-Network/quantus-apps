import 'package:quantus_sdk/quantus_sdk.dart';

const usdcEth = SwapToken(
  assetId: 'nep141:usdc.omft.near',
  symbol: 'USDC',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
  imageUrl: 'https://img.test/usdc.png',
  networkImageUrl: 'https://img.test/eth.png',
  marketCapUsd: 1e9,
);
const qtc = SwapToken(
  assetId: 'nep141:qtc.omft.near',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.1,
  isQuantus: true,
);

SwapQuote quoteOutOfQtc({required DateTime deadline}) => SwapQuote(
  fromToken: qtc,
  toToken: usdcEth,
  swapType: SwapType.exactOutput,
  amountIn: BigInt.from(250) * BigInt.from(10).pow(AppConstants.decimals),
  minAmountIn: BigInt.from(248) * BigInt.from(10).pow(AppConstants.decimals),
  amountOut: BigInt.from(24860000),
  minAmountOut: BigInt.from(24611400),
  amountInUsd: 25,
  amountOutUsd: 24.86,
  slippageBps: 100,
  refundAddress: 'qzrefund',
  recipient: '0xrecipient',
  deadline: deadline,
  timeEstimate: const Duration(seconds: 90),
  correlationId: 'corr',
  signature: 'ed25519:sig',
  depositAddress: 'qzdeposit',
  depositMemo: '4183920',
);

/// A swap out of QTC in [status] with every optional field set, so a round
/// trip shows them all.
ActiveSwap activeSwapIn(
  SwapStatus status, {
  required DateTime startedAt,
  required DateTime deadline,
  bool byHand = false,
}) => ActiveSwap(
  order: SwapOrder(
    quote: quoteOutOfQtc(deadline: deadline),
    status: status,
    amountOut: BigInt.from(24900000),
    refundedAmount: BigInt.one,
    refundReason: 'No liquidity',
    originTxHashes: const ['0xorigin'],
    destinationTxHashes: const ['0xdest'],
  ),
  accountId: 'qzaccount',
  accountName: 'Account 1',
  startedAt: startedAt,
  depositByHand: byHand,
  depositTxHash: '0xtx',
  depositFee: BigInt.from(20000000000),
);
