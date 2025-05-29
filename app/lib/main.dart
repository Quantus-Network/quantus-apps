/// Public entry‑point for the Quantus SDK.
///
/// This simple stub lets dependent apps compile before the real
/// FFI and RPC wiring is implemented.
library quantus_sdk;

/// Central SDK object (placeholder).
///
/// Call [init] once at app start‑up to perform any async setup,
/// e.g. loading a Rust dynamic library or reading cached config.
class QuantusSdk {
  /// Initialise the SDK (currently a no‑op).
  static Future<void> init() async {
    // TODO: load Rust FFI, read settings, etc.
  }
}
