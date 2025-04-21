#! /bin/bash

echo "Generating Rust bindings..."
flutter_rust_bridge_codegen generate

echo "Generating Polkadart bindings..."

dart run polkadart_cli:generate -v
dart fix --apply

echo "Done!"