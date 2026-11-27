import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/utils/serial_queue.dart';

/// Changes to which wallet numbers are in use, one at a time: removing a
/// wallet's accounts, and adding a wallet at the next free number (New
/// Wallet, Import Wallet, a first cold wallet). The device's storage frees a
/// wallet's number before it has deleted that wallet's settings and recovery
/// phrase; a wallet added in between would take the number, then lose what it
/// had just stored there. In this queue the next wallet's number is read only
/// once the removal before it has finished.
///
/// Not the navigation queue ([shellNavigationProvider]): that drops the steps
/// waiting in it when an account switch fails, and a removal that was asked
/// for and approved must not be dropped.
final walletSlotsProvider = Provider<SerialQueue>((ref) => SerialQueue());
