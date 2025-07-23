#! /bin/bash

echo "Generating Rust bindings..."
flutter_rust_bridge_codegen generate

echo "Deleting old Polkadart bindings"
rm -rf lib/generated

echo "Generating Polkadart bindings..."

dart run polkadart_cli:generate -v
dart fix --apply

echo "Done!"