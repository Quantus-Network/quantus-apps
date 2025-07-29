#!/bin/bash
set -e

# Get the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Ensuring Rust library is up to date..."
"$DIR/test/build_library.sh"

echo "Running Flutter tests..."
(cd "$DIR" && flutter test)