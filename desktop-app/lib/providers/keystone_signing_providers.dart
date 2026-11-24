import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Makes the collector of the frames of a cold wallet's signature, one per
/// scan. Its checks run in Rust.
final signatureCollectorFactoryProvider = Provider<UrScanAccumulator Function()>((ref) => UrScanAccumulator.new);
