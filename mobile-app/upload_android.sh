#!/bin/sh

set -eu

cd "$(dirname "$0")"
. ./build_defines.sh

flutter build appbundle --no-pub $DEFINES

open build/app/outputs/bundle/release
