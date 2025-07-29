#!/bin/bash
set -e

echo "Building Rust library for local development and testing..."
(cd rust && cargo build --release)
echo "Rust library built successfully." 